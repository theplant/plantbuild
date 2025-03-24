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
    local hpa = k.autoscaling.v2.horizontalPodAutoscaler;
    local pdb = k.policy.v1.podDisruptionBudget;
    local metric = k.autoscaling.v2.metricSpec;

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
      withIRSA + [
        hpa.new(name)
        + hpa.metadata.withNamespace(namespace)
        + hpa.spec.scaleTargetRef.withApiVersion('apps/v1')
        + hpa.spec.scaleTargetRef.withKind('Deployment')
        + hpa.spec.scaleTargetRef.withName(name)
        + hpa.spec.withMinReplicas(minReplicas)
        + hpa.spec.withMaxReplicas(if maxReplicas != null then maxReplicas else minReplicas * 2)
        + hpa.spec.withMetrics(
          std.filter(
            function(x) x != null,
            [cpuMetric, memoryMetric]
          )
        )
        + hpaMixin,
      ]
    else
      withIRSA;

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
}
