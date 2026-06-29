local envoy_gw = import 'envoy-gw.libsonnet';
local gw_api = import 'gw-api.libsonnet';
local k = import 'k.libsonnet';

{
  local root = self,
  local ctn = k.core.v1.container,
  local deployment = k.apps.v1.deployment,

  pod_antiaffinity_for(name, neverColocated=false)::
    local affinityTerm = {
      labelSelector: {
        matchExpressions: [{
          key: 'app',
          operator: 'In',
          values: [name],
        }],
      },
      topologyKey: 'kubernetes.io/hostname',
    };
    if neverColocated then
      k.core.v1.podAntiAffinity.withRequiredDuringSchedulingIgnoredDuringExecution([affinityTerm])
    else
      k.core.v1.podAntiAffinity.withPreferredDuringSchedulingIgnoredDuringExecution([{ weight: 100, podAffinityTerm: affinityTerm }]),

  deployment(
    namespace='default',
    name,
    image='',
    envmap={},
    replicas=null,
    ports=4000,  // New parameter supporting multiple ports
    withoutProbe=false,
    probes={},
    neverColocated=false,
    requests={ cpu: '20m', memory: '50Mi' },
    limits={ memory: '100Mi' },
    maxSurge=1,
    container={},
    terminationGracePeriodSeconds=30,
  )::
    local labels = { app: name };

    // Convert single port to ports array for backward compatibility
    local normalizedPorts = if std.type(ports) == 'array' && std.length(ports) > 0
    then ports
    else [{ name: 'app', containerPort: if std.type(ports) == 'number' then ports else 4000 }];

    // Default probe configuration
    local lp = ctn.livenessProbe;
    local rp = ctn.readinessProbe;
    local defaultProbe = if withoutProbe then {}
    else if std.objectHas(probes, 'livenessProbe') || std.objectHas(probes, 'readinessProbe') then probes
    else lp.tcpSocket.withPort(normalizedPorts[0].containerPort)
         + lp.withFailureThreshold(3)
         + lp.withInitialDelaySeconds(360)
         + lp.withPeriodSeconds(10)
         + lp.withSuccessThreshold(1)

         + rp.tcpSocket.withPort(normalizedPorts[0].containerPort)
         + rp.withFailureThreshold(80)
         + rp.withInitialDelaySeconds(5)
         + rp.withPeriodSeconds(5)
         + rp.withSuccessThreshold(1);

    k.apps.v1.deployment.new(
      name=name,
      replicas=replicas,
      containers=[
        ctn.new(name, image)
        + ctn.withImagePullPolicy('IfNotPresent')
        + ctn.withPorts(normalizedPorts)
        + ctn.resources.withLimits(limits)
        + ctn.resources.withRequests(requests)
        + (if !withoutProbe then { livenessProbe: defaultProbe.livenessProbe } else {})
        + (if !withoutProbe then { readinessProbe: defaultProbe.readinessProbe } else {})
        + ctn.withEnvMap(envmap)
        + container,
      ],
      podLabels=labels,
    )
    + deployment.metadata.withNamespace(namespace)
    + deployment.metadata.withLabels(labels)
    + deployment.spec.strategy.withType('RollingUpdate')
    + deployment.spec.strategy.rollingUpdate.withMaxSurge(maxSurge)
    + deployment.spec.strategy.rollingUpdate.withMaxUnavailable(0)
    + (if std.length(std.toString(terminationGracePeriodSeconds)) > 0 then deployment.spec.template.spec.withTerminationGracePeriodSeconds(terminationGracePeriodSeconds) else {})
    + {
      spec+: {
        template+: {
          spec+: {
            affinity: {
              podAntiAffinity: root.pod_antiaffinity_for(name, neverColocated),
            },
          },
        },
      },
    },

  single_svc_ingress(
    namespace='default',
    name,
    port,
    host='',
    path='/',
    ingressTLSEnabled=false,
  )::
    local ingress = k.networking.v1.ingress;
    local rule = k.networking.v1.ingressRule;
    local httpIngressPath = k.networking.v1.httpIngressPath;

    local hosts = if std.type(host) == 'array' then host
    else if host != '' then [host]
    else [''];

    local rules = if std.length(hosts) > 0 && hosts[0] != '' then
      [
        rule.withHost(h) + rule.http.withPaths([
          httpIngressPath.withPath(path)
          + httpIngressPath.withPathType('Prefix')
          + httpIngressPath.backend.service.withName(name)
          + httpIngressPath.backend.service.port.withNumber(port),
        ])
        for h in hosts
      ]
    else
      [rule.http.withPaths([
        httpIngressPath.withPath(path)
        + httpIngressPath.withPathType('Prefix')
        + httpIngressPath.backend.service.withName(name)
        + httpIngressPath.backend.service.port.withNumber(port),
      ])];

    local tls = if ingressTLSEnabled && std.length(hosts) > 0 && hosts[0] != '' then
      [{ hosts: hosts, secretName: std.format('%s-tls', name) }]
    else
      [];

    ingress.new(name)
    + ingress.metadata.withNamespace(namespace)
    + ingress.spec.withIngressClassName('nginx')
    + ingress.spec.withRules(rules)
    + (if std.length(tls) > 0 then ingress.spec.withTls(tls) else {}),

  hpa_for(
    namespace,
    name,
    minReplicas,
    maxReplicas=null,
    targetCPUUtilizationPercentage=75,
    targetMemoryUtilizationPercentage=75,
    hpaMixin={},
  )::
    local hpa = k.autoscaling.v2.horizontalPodAutoscaler;
    local metric = k.autoscaling.v2.metricSpec;
    local cpuMetric = if targetCPUUtilizationPercentage != null then
      metric.withType('Resource')
      + metric.resource.withName('cpu')
      + metric.resource.target.withType('Utilization')
      + metric.resource.target.withAverageUtilization(targetCPUUtilizationPercentage);
    local memoryMetric = if targetMemoryUtilizationPercentage != null then
      metric.withType('Resource')
      + metric.resource.withName('memory')
      + metric.resource.target.withType('Utilization')
      + metric.resource.target.withAverageUtilization(targetMemoryUtilizationPercentage);
    hpa.new(name)
    + hpa.metadata.withNamespace(namespace)
    + hpa.spec.scaleTargetRef.withApiVersion('apps/v1')
    + hpa.spec.scaleTargetRef.withKind('Deployment')
    + hpa.spec.scaleTargetRef.withName(name)
    + hpa.spec.withMinReplicas(minReplicas)
    + hpa.spec.withMaxReplicas(if maxReplicas != null then maxReplicas else minReplicas * 2)
    + hpa.spec.withMetrics(
      std.filter(function(x) x != null, [cpuMetric, memoryMetric])
    )
    + hpaMixin,

  // serviceFor create service for a given deployment.
  service_for(deployment, ignored_labels=[], nameFormat='%(container)s-%(port)s')::
    local service = k.core.v1.service;
    local servicePort = k.core.v1.servicePort;
    local ports = [
      servicePort.newNamed(
        name=(nameFormat % { container: c.name, port: port.name }),
        port=port.containerPort,
        targetPort=port.containerPort
      ) +
      if std.objectHas(port, 'protocol')
      then servicePort.withProtocol(port.protocol)
      else {}
      for c in deployment.spec.template.spec.containers
      for port in (c + ctn.withPortsMixin([])).ports
    ];
    local labels = {
      [x]: deployment.spec.template.metadata.labels[x]
      for x in std.objectFields(deployment.spec.template.metadata.labels)
      if std.count(ignored_labels, x) == 0
    };

    service.new(
      deployment.metadata.name,  // name
      labels,  // selector
      ports,
    ) +
    service.mixin.metadata.withLabels({ name: deployment.metadata.name }),

  image_to_url(
    namespace='default',
    name,
    host='',
    path='/',
    envmap={},
    replicas=null,
    image='',
    port=80,
    withoutProbe=false,
    probes={},
    neverColocated=false,
    requests={ cpu: '20m', memory: '50Mi' },
    limits={ memory: '100Mi' },
    maxSurge=1,
    terminationGracePeriodSeconds=30,
    ingressTLSEnabled=false,
    minReplicas=null,
    maxReplicas=null,
    targetCPUUtilizationPercentage=75,
    targetMemoryUtilizationPercentage=75,
    minAvailable=null,
    irsaArn='',
    container={},
    deploymentMixin={},
    serviceMixin={},
    ingressMixin={},
    irsaMixin={},
    hpaMixin={},
    pdbMixin={},
  )::
    local d = root.deployment(
                namespace=namespace,
                name=name,
                envmap=envmap,
                replicas=replicas,
                image=image,
                ports=port,
                withoutProbe=withoutProbe,
                probes=probes,
                neverColocated=neverColocated,
                requests=requests,
                limits=limits,
                maxSurge=maxSurge,
                terminationGracePeriodSeconds=terminationGracePeriodSeconds,
                container=container,
              )
              + (if irsaArn != '' then deployment.spec.template.spec.withServiceAccountName(name) else {})
              + deploymentMixin;

    local s = root.service_for(d)
              + k.core.v1.service.metadata.withNamespace(namespace)
              + serviceMixin;

    local selectedPort =
      if std.type(port) == 'array' then
        if std.filter(function(p) p.name == 'http', port) != [] then
          std.filter(function(p) p.name == 'http', port)[0].containerPort
        else
          port[0].containerPort
      else
        port;

    local i = root.single_svc_ingress(
      namespace=namespace,
      name=name,
      port=selectedPort,
      host=host,
      path=path,
      ingressTLSEnabled=ingressTLSEnabled,
    ) + ingressMixin;

    local items = [d, s, i];

    local withIRSA = if irsaArn != '' then
      items + [
        k.core.v1.serviceAccount.new(name)
        + k.core.v1.serviceAccount.metadata.withNamespace(namespace)
        + k.core.v1.serviceAccount.metadata.withName(name)
        + k.core.v1.serviceAccount.metadata.withAnnotations({ 'eks.amazonaws.com/role-arn': irsaArn })
        + irsaMixin,
      ]
    else
      items;

    local withHPA = if minReplicas != null then
      withIRSA + [root.hpa_for(
        namespace=namespace,
        name=name,
        minReplicas=minReplicas,
        maxReplicas=maxReplicas,
        targetCPUUtilizationPercentage=targetCPUUtilizationPercentage,
        targetMemoryUtilizationPercentage=targetMemoryUtilizationPercentage,
        hpaMixin=hpaMixin,
      )]
    else
      withIRSA;

    local pdb = k.policy.v1.podDisruptionBudget;
    local withPDB = if (replicas != null && replicas > 1) || minAvailable != null then
      withHPA + [
        pdb.new(name)
        + pdb.metadata.withNamespace(namespace)
        + pdb.spec.withMinAvailable(if minAvailable != null then minAvailable else 1)
        + pdb.spec.selector.withMatchLabels({ app: name })
        + pdbMixin,
      ]
    else
      withHPA;

    k.core.v1.list.new(withPDB),

  gateway_resources(
    namespace='default',
    name,
    hostname,
    tlsCertSecretName,
    gatewayClassName='eg',
    httpsAllowedNamespaces=[],
    enableCloudfrontIPDetection=false,
    clusterIssuer='letsencrypt-gateway',
    extraListeners=[],
    compression=true,
  )::
    local gateway = gw_api.gateway.v1.gateway;
    local listeners = gateway.spec.listeners;
    local tls = listeners.tls;
    local httpRoute = gw_api.gateway.v1.httpRoute;
    local parentRefs = httpRoute.spec.parentRefs;
    local filters = httpRoute.spec.rules.filters;
    local clientTrafficPolicy = envoy_gw.gateway.v1alpha1.clientTrafficPolicy;
    local backendTrafficPolicy = envoy_gw.gateway.v1alpha1.backendTrafficPolicy;
    local targetRefs = clientTrafficPolicy.spec.targetRefs;

    local httpsListener =
      listeners.withName('https')
      + listeners.withPort(443)
      + listeners.withProtocol('HTTPS')
      + listeners.withHostname(hostname)
      + (if std.length(httpsAllowedNamespaces) > 0 then
           listeners.allowedRoutes.namespaces.withFrom('Selector')
           + listeners.allowedRoutes.namespaces.selector.withMatchExpressions([{
             key: 'kubernetes.io/metadata.name',
             operator: 'In',
             values: httpsAllowedNamespaces,
           }])
         else
           listeners.allowedRoutes.namespaces.withFrom('Same'))
      + tls.withMode('Terminate')
      + tls.withCertificateRefs([
        tls.certificateRefs.withName(tlsCertSecretName)
        + tls.certificateRefs.withGroup('')
        + tls.certificateRefs.withKind('Secret'),
      ]);

    local gw =
      gateway.new(name)
      + gateway.metadata.withNamespace(namespace)
      + gateway.metadata.withAnnotations({ 'cert-manager.io/cluster-issuer': clusterIssuer })
      + gateway.spec.withGatewayClassName(gatewayClassName)
      + gateway.spec.withListeners(
        [
          listeners.withName('http')
          + listeners.withPort(80)
          + listeners.withProtocol('HTTP')
          + listeners.allowedRoutes.namespaces.withFrom('Same'),
          httpsListener,
        ] + extraListeners
      );

    local route =
      httpRoute.new(name + '-tls-redirect')
      + httpRoute.metadata.withNamespace(namespace)
      + httpRoute.spec.withParentRefs(
        parentRefs.withName(name)
        + parentRefs.withNamespace(namespace)
        + parentRefs.withSectionName('http')
      )
      + httpRoute.spec.withRules([
        httpRoute.spec.rules.withFilters([
          filters.withType('RequestRedirect')
          + filters.requestRedirect.withScheme('https')
          + filters.requestRedirect.withStatusCode(301),
        ]),
      ]);

    local btp = backendTrafficPolicy.new(name + '-response-compression')
                + backendTrafficPolicy.metadata.withNamespace(namespace)
                + backendTrafficPolicy.spec.withTargetRefs(
                  backendTrafficPolicy.spec.targetRefs.withGroup('gateway.networking.k8s.io')
                  + backendTrafficPolicy.spec.targetRefs.withKind('Gateway')
                  + backendTrafficPolicy.spec.targetRefs.withName(name)
                )
                + backendTrafficPolicy.spec.withCompressor([
                  backendTrafficPolicy.spec.compressor.withType('Brotli')
                  + backendTrafficPolicy.spec.compressor.withBrotli({})
                  + backendTrafficPolicy.spec.compressor.withMinContentLength(1024),
                  backendTrafficPolicy.spec.compressor.withType('Gzip')
                  + backendTrafficPolicy.spec.compressor.withGzip({})
                  + backendTrafficPolicy.spec.compressor.withMinContentLength(1024),
                  backendTrafficPolicy.spec.compressor.withType('Zstd')
                  + backendTrafficPolicy.spec.compressor.withZstd({})
                  + backendTrafficPolicy.spec.compressor.withMinContentLength(1024),
                ]);

    local items = [gw, route]
                  + (if compression then [btp] else [])
                  + (if enableCloudfrontIPDetection then [
                       clientTrafficPolicy.new(name + '-cloudfront-trusted-ips')
                       + clientTrafficPolicy.metadata.withNamespace(namespace)
                       + clientTrafficPolicy.spec.withTargetRefs(
                         targetRefs.withGroup('gateway.networking.k8s.io')
                         + targetRefs.withKind('Gateway')
                         + targetRefs.withName(name)
                       )
                       + clientTrafficPolicy.spec.clientIPDetection.xForwardedFor.withTrustedCIDRs(
                         // curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq -r '[.prefixes[] | select(.service=="CLOUDFRONT") | .ip_prefix]'
                         [
                           '23.228.249.0/24',
                           '120.52.22.96/27',
                           '23.228.222.0/24',
                           '205.251.249.0/24',
                           '180.163.57.128/26',
                           '23.228.220.0/24',
                           '204.246.168.0/22',
                           '111.13.171.128/26',
                           '18.160.0.0/15',
                           '205.251.252.0/23',
                           '54.192.0.0/16',
                           '204.246.173.0/24',
                           '23.228.244.0/24',
                           '54.230.200.0/21',
                           '120.253.240.192/26',
                           '23.234.192.0/18',
                           '116.129.226.128/26',
                           '130.176.0.0/17',
                           '3.173.192.0/18',
                           '108.156.0.0/14',
                           '99.86.0.0/16',
                           '23.228.214.0/24',
                           '23.228.213.0/24',
                           '13.32.0.0/15',
                           '120.253.245.128/26',
                           '13.224.0.0/14',
                           '70.132.0.0/18',
                           '15.158.0.0/16',
                           '111.13.171.192/26',
                           '13.249.0.0/16',
                           '18.238.0.0/15',
                           '18.244.0.0/15',
                           '205.251.208.0/20',
                           '3.165.0.0/16',
                           '3.168.0.0/14',
                           '23.228.251.0/24',
                           '65.9.128.0/18',
                           '130.176.128.0/18',
                           '23.228.221.0/24',
                           '23.228.248.0/24',
                           '58.254.138.0/25',
                           '205.251.206.0/23',
                           '54.230.208.0/20',
                           '3.160.0.0/14',
                           '116.129.226.0/25',
                           '23.91.0.0/19',
                           '52.222.128.0/17',
                           '18.164.0.0/15',
                           '111.13.185.32/27',
                           '64.252.128.0/18',
                           '205.251.254.0/24',
                           '3.166.0.0/15',
                           '54.230.224.0/19',
                           '71.152.0.0/17',
                           '216.137.32.0/19',
                           '204.246.172.0/24',
                           '205.251.202.0/23',
                           '18.172.0.0/15',
                           '120.52.39.128/27',
                           '118.193.97.64/26',
                           '3.164.64.0/18',
                           '18.154.0.0/15',
                           '3.173.0.0/17',
                           '54.240.128.0/18',
                           '205.251.250.0/23',
                           '180.163.57.0/25',
                           '52.46.0.0/18',
                           '3.174.0.0/15',
                           '52.82.128.0/19',
                           '54.230.0.0/17',
                           '54.230.128.0/18',
                           '54.239.128.0/18',
                           '130.176.224.0/20',
                           '36.103.232.128/26',
                           '52.84.0.0/15',
                           '143.204.0.0/16',
                           '144.220.0.0/16',
                           '120.52.153.192/26',
                           '23.228.250.0/24',
                           '119.147.182.0/25',
                           '120.232.236.0/25',
                           '111.13.185.64/27',
                           '3.164.0.0/18',
                           '3.172.64.0/18',
                           '54.182.0.0/16',
                           '58.254.138.128/26',
                           '120.253.245.192/27',
                           '54.239.192.0/19',
                           '18.68.0.0/16',
                           '18.64.0.0/14',
                           '120.52.12.64/26',
                           '24.110.32.0/19',
                           '99.84.0.0/16',
                           '205.251.204.0/23',
                           '130.176.192.0/19',
                           '23.228.223.0/24',
                           '23.228.212.0/24',
                           '52.124.128.0/17',
                           '204.246.164.0/22',
                           '13.35.0.0/16',
                           '204.246.174.0/23',
                           '3.164.128.0/17',
                           '24.110.128.0/17',
                           '3.172.0.0/18',
                           '36.103.232.0/25',
                           '119.147.182.128/26',
                           '118.193.97.128/25',
                           '120.232.236.128/26',
                           '204.246.176.0/20',
                           '65.8.0.0/16',
                           '65.9.0.0/17',
                           '108.138.0.0/15',
                           '120.253.241.160/27',
                           '3.173.128.0/18',
                           '51.74.192.0/18',
                           '64.252.64.0/18',
                           '13.113.196.64/26',
                           '13.113.203.0/24',
                           '52.199.127.192/26',
                           '57.182.253.0/24',
                           '57.183.42.0/25',
                           '13.124.199.0/24',
                           '3.35.130.128/25',
                           '52.78.247.128/26',
                           '13.203.133.0/26',
                           '13.233.177.192/26',
                           '15.207.13.128/25',
                           '15.207.213.128/25',
                           '52.66.194.128/26',
                           '13.228.69.0/24',
                           '47.129.82.0/24',
                           '47.129.83.0/24',
                           '47.129.84.0/24',
                           '52.220.191.0/26',
                           '13.210.67.128/26',
                           '13.54.63.128/26',
                           '3.107.43.128/25',
                           '3.107.44.0/25',
                           '3.107.44.128/25',
                           '43.218.56.128/26',
                           '43.218.56.192/26',
                           '43.218.56.64/26',
                           '43.218.71.0/26',
                           '99.79.169.0/24',
                           '18.192.142.0/23',
                           '18.199.68.0/22',
                           '18.199.72.0/22',
                           '18.199.76.0/22',
                           '35.158.136.0/24',
                           '52.57.254.0/24',
                           '18.200.212.0/23',
                           '52.212.248.0/26',
                           '13.134.24.0/23',
                           '13.134.94.0/23',
                           '18.175.65.0/24',
                           '18.175.66.0/24',
                           '18.175.67.0/24',
                           '3.10.17.128/25',
                           '3.11.53.0/24',
                           '52.56.127.0/25',
                           '15.188.184.0/24',
                           '51.44.234.0/23',
                           '51.44.236.0/23',
                           '51.44.238.0/23',
                           '52.47.139.0/24',
                           '3.29.40.128/26',
                           '3.29.40.192/26',
                           '3.29.40.64/26',
                           '3.29.57.0/26',
                           '18.229.220.192/26',
                           '18.230.229.0/24',
                           '18.230.230.0/25',
                           '54.233.255.128/26',
                           '56.125.46.0/24',
                           '56.125.47.0/32',
                           '56.125.48.0/24',
                           '3.231.2.0/25',
                           '3.234.232.224/27',
                           '3.236.169.192/26',
                           '3.236.48.0/23',
                           '34.195.252.0/24',
                           '34.226.14.0/24',
                           '44.220.194.0/23',
                           '44.220.196.0/23',
                           '44.220.198.0/23',
                           '44.220.200.0/23',
                           '44.220.202.0/23',
                           '44.222.66.0/24',
                           '13.59.250.0/26',
                           '18.216.170.128/25',
                           '3.128.93.0/24',
                           '3.134.215.0/24',
                           '3.146.232.0/22',
                           '3.147.164.0/22',
                           '3.147.244.0/22',
                           '52.15.127.128/26',
                           '3.101.158.0/23',
                           '52.52.191.128/26',
                           '34.216.51.0/25',
                           '34.223.12.224/27',
                           '34.223.80.192/26',
                           '35.162.63.192/26',
                           '35.167.191.128/26',
                           '35.93.168.0/23',
                           '35.93.170.0/23',
                           '35.93.172.0/23',
                           '44.227.178.0/24',
                           '44.234.108.128/25',
                           '44.234.90.252/30',
                         ]
                       ),
                     ]
                     else []);

    k.core.v1.list.new(items),
}
