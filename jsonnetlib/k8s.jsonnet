local cfg = import 'config.jsonnet';
cfg {
  local root = self,
  local fullimage(namespace, name) = root.with_registry('%s/%s:%s' % [namespace, name, root.version]),
  local imageWithVersionAsTag(image) = '%s:%s' % [image, root.version],
  local resolve_image(namespace, name, image) = if std.length(image) == 0 then
    fullimage(namespace, name)
  else if std.length(std.split(image, ':')) == 1 then
    imageWithVersionAsTag(image)
  else
    image,
  local configmapref(configmap) = if std.length(configmap) > 0 then {
    envFrom: [
      {
        configMapRef: {
          name: configmap,
        },
      },
    ],
  } else {},
  local imagePullSecretsRef(imagePullSecrets) = if std.length(imagePullSecrets) > 0 then
    {
      imagePullSecrets: [
        {
          name: imagePullSecrets,
        },
      ],
    } else {},
  local envRef(envmap, env) = if std.length(std.objectFields(envmap)) > 0 then
    {
      env: [
        {
          name: n,
          value: envmap[n],
        }
        for n in std.objectFields(envmap)
      ] + env,
    } else { env: env },

  configmap(
    namespace=root.defaultNamespace,
    name,
    deployment='',
    cronjob='',
    job='',
    data,
    withoutVersion=false
  ):: {
    assert !(std.length(deployment) == 0 && std.length(cronjob) == 0 && std.length(job) == 0) : 'deployment or cronjob or job required',
    local labels = if std.length(deployment) > 0 then
      { deployment: deployment }
    else if std.length(cronjob) > 0 then
      { cronjob: cronjob }
    else if std.length(job) > 0 then
      { job: job }
    else
      {},
    kind: 'ConfigMap',
    apiVersion: 'v1',
    metadata: {
      namespace: namespace,
      name: if withoutVersion then name else '%s-%s' % [name, root.version],
      labels: labels,
    },
    data: data,
  },

  cronjob(
    namespace=root.defaultNamespace,
    name,
    schedule,
    configmap='',
    image='',
    imagePullSecrets=root.imagePullSecrets,
    envmap={},
    env=[],
    container={},
    volumes=[],
    podSpec=root.podSpec,
    cronjobSpec=root.cronjobSpec,
    cpuRequest=root.cronCPURequest,
    cpuLimit=root.cronCPULimit,
    memoryRequest=root.cronMemoryRequest,
    memoryLimit=root.cronMemoryLimit,
  ):: {
    local vols = if std.length(volumes) > 0 then
      {
        volumes: volumes,
      } else {},
    kind: 'CronJob',
    apiVersion: 'batch/v1',
    metadata: {
      namespace: namespace,
      name: name,
      labels: {
        app: name,
        cronjob: name,
      },
    },
    spec: {
      schedule: schedule,
      concurrencyPolicy: 'Allow',
      failedJobsHistoryLimit: root.failedJobsHistoryLimit,
      successfulJobsHistoryLimit: root.successfulJobsHistoryLimit,
      jobTemplate: {
        metadata: {
          labels: {
            app: name,
          },
        },
        spec: {
          backoffLimit: 0,
          template: {
            metadata: {
              labels: {
                app: name,
              },
            },
            spec: {
              restartPolicy: 'Never',
              containers: [
                {
                  name: name,
                  image: resolve_image(namespace, name, image),
                  imagePullPolicy: 'IfNotPresent',
                  resources: {
                    limits: {
                      cpu: cpuLimit,
                      memory: memoryLimit,
                    },
                    requests: {
                      cpu: cpuRequest,
                      memory: memoryRequest,
                    },
                  },
                } + configmapref(configmap) + envRef(envmap, env) + container,
              ],
            } + vols + imagePullSecretsRef(imagePullSecrets) + podSpec,
          },
        },
      },
    } + cronjobSpec,
  },

  job(
    namespace=root.defaultNamespace,
    name,
    configmap='',
    image='',
    imagePullSecrets=root.imagePullSecrets,
    envmap={},
    env=[],
    container={},
    podSpec=root.podSpec,
  ):: {
    kind: 'Job',
    apiVersion: 'batch/v1',
    metadata: {
      namespace: namespace,
      name: name,
      labels: {
        app: name,
        job: name,
      },
    },
    spec: {
      //   ttlSecondsAfterFinished: 5, // not supported yet
      backoffLimit: 1,
      parallelism: 1,
      template: {
        spec: {
          restartPolicy: 'Never',
          containers: [
            {
              name: name,
              image: resolve_image(namespace, name, image),
              imagePullPolicy: 'IfNotPresent',
            } + configmapref(configmap) + envRef(envmap, env) + container,
          ],
        } + imagePullSecretsRef(imagePullSecrets) + podSpec,
      },
    },
  },

  secret(
    namespace=root.defaultNamespace,
    name,
    data,
    type='',
    annotations={},
  ):: {
    kind: 'Secret',
    apiVersion: 'v1',
    data: data,
    metadata: {
      annotations: annotations,
      namespace: namespace,
      name: name,
    },
    type: if std.length(type) > 0 then
      type
    else
      if std.objectHas(data, '.dockerconfigjson') then
        'kubernetes.io/dockerconfigjson'
      else if std.objectHas(data, '.dockercfg') then
        'kubernetes.io/dockercfg'
      else if std.objectHas(data, 'ca.crt') && std.objectHas(data, 'token') then
        'kubernetes.io/service-account-token'
      else
        'Opaque',
  },

  namespace(
    name=root.defaultNamespace,
  ):: {

    kind: 'Namespace',
    apiVersion: 'v1',
    metadata: {
      name: name,
    },
  },

  set_images(
    namespace=root.defaultNamespace,
    images
  ):: {
    local make_items(items) = if std.type(items) == 'array' then
      items
    else
      [items],

    commands: ['-n %s set image %s/%s %s=%s' % [namespace, it.type, it.name, it.name, resolve_image(namespace, it.name, it.image)] for it in make_items(images)],
  },

  patch_deployment_image(
    namespace=root.defaultNamespace,
    name,
    image='',
  ):: [
    {
      op: 'replace',
      path: '/spec/template/spec/containers/0/image',
      value: resolve_image(namespace, name, image),
    },
  ],

  patch_deployment_env(
    configmap,
  ):: [
    {
      op: 'replace',
      path: '/spec/template/spec/containers/0/envFrom',
      value: [
        {
          configMapRef: {
            name: configmap,
          },
        },
      ],
    },
  ],

  patch_cronjob_env(
    configmap,
  ):: [
    {
      op: 'replace',
      path: '/spec/jobTemplate/spec/template/spec/containers/0/envFrom',
      value: [
        {
          configMapRef: {
            name: configmap,
          },
        },
      ],
    },
  ],

  patch_job_env(
    configmap,
  ):: [
    {
      op: 'replace',
      path: '/spec/containers/0/envFrom',
      value: [
        {
          configMapRef: {
            name: configmap,
          },
        },
      ],
    },
  ],

  list(items)::
    local make_items(items) = if std.type(items) == 'array' then
      [make_items(it) for it in items]
    else if std.type(items) == 'object' && items.kind == 'List' then
      items.items
    else
      [items];
    { apiVersion: 'v1' } +
    { kind: 'List' } +
    { items: std.flattenArrays(make_items(items)) },

  image_to_url(
    namespace=root.defaultNamespace,
    name,
    host='',
    ingressTLSEnabled=false,
    path='/',
    configmap='',
    replicas=1,
    minAvailable=root.minAvailable,
    imagePullSecrets=root.imagePullSecrets,
    image='',
    port=root.port,
    probes={},
    targetPort=root.port,
    neverColocated=false,
    memoryRequest=root.memoryRequest,
    cpuRequest=root.cpuRequest,
    memoryLimit=root.memoryLimit,
    cpuLimit=root.cpuLimit,
    maxSurge=root.maxSurge,
    ingressAnnotations={},
    envmap={},
    env=[],
    container={},
    volumes=[],
    terminationGracePeriodSeconds=root.terminationGracePeriodSeconds,
    minReplicas=2,
    maxReplicas=3,
    targetCPUUtilizationPercentage=75,
    podSpec=root.podSpec,
  ):: {
    apiVersion: 'v1',
    kind: 'List',
    items: [
      root.deployment(
        namespace=namespace,
        name=name,
        image=image,
        port=port,
        probes=probes,
        configmap=configmap,
        replicas=replicas,
        imagePullSecrets=imagePullSecrets,
        neverColocated=neverColocated,
        memoryRequest=memoryRequest,
        cpuRequest=cpuRequest,
        memoryLimit=memoryLimit,
        cpuLimit=cpuLimit,
        maxSurge=maxSurge,
        envmap=envmap,
        env=env,
        container=container,
        volumes=volumes,
        terminationGracePeriodSeconds=terminationGracePeriodSeconds,
        podSpec=podSpec,
      ),
      root.svc(namespace, name, port, targetPort),
      root.single_svc_ingress(
        namespace=namespace,
        name=name,
        port=port,
        host=host,
        ingressTLSEnabled=ingressTLSEnabled,
        path=path,
        annotations=ingressAnnotations,
      ),
    ] + (if replicas > 1 && maxReplicas > 1 then [
           root.hpa(namespace, name, minReplicas, maxReplicas, targetCPUUtilizationPercentage),
         ] else []) + if replicas > 1 then [
      root.pdb(namespace, name, minAvailable),
    ] else [],
  },

  svc(namespace=root.defaultNamespace, name, port=root.port, targetPort=root.port, annotations={}):: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: name,
      namespace: namespace,
      annotations: annotations,
      labels: {
        app: name,
      },
    },
    spec: {
      type: 'ClusterIP',
      ports: [
        {
          name: 'app',
          port: port,
          targetPort: targetPort,
        },
      ],
      selector: {
        app: name,
      },
    },
  },

  single_svc_ingress(namespace=root.defaultNamespace, name, port, host='', path='/', ingressTLSEnabled=false, annotations={})::
    local newhost = if std.type(host) != 'array' && std.length(host) == 0 && std.length(root.baseHost) > 0 then '%s.%s' % [name, root.baseHost] else host;
    local hosts = if std.type(host) == 'array' then host else [newhost];
    local rules = [
      {
        host: h,
        http: {
          paths: [
            {
              path: path,
              pathType: root.pathType,
              backend: {
                service: {
                  name: name,
                  port: {
                    number: port,
                  },
                },
              },
            },
          ],
        },
      }
      for h in hosts
    ];
    local tls = if !ingressTLSEnabled then [] else [
      {
        secretName: std.join('-', [name, 'ssl']),
        hosts: [h for h in hosts],
      },
    ];
    root.ingress(namespace, name, rules, tls, annotations),

  ingress(namespace=root.defaultNamespace, name, rules, tls=[], annotations={}):: {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'Ingress',
    metadata: {
      name: name,
      namespace: namespace,
      annotations: annotations,
      labels: {
        app: name,
      },
    },
    spec: {
      ingressClassName: root.ingressClassName,
      rules: rules,
      tls: tls,
    },
  },

  deployment(
    namespace=root.defaultNamespace,
    name,
    configmap='',
    envmap={},
    env=[],
    replicas=root.replicas,
    imagePullSecrets=root.imagePullSecrets,
    image='',
    port=root.port,
    probes={},
    withoutProbe=false,
    neverColocated=false,
    memoryRequest=root.memoryRequest,
    cpuRequest=root.cpuRequest,
    memoryLimit=root.memoryLimit,
    cpuLimit=root.cpuLimit,
    maxSurge=root.maxSurge,
    container={},
    volumes=[],
    terminationGracePeriodSeconds=root.terminationGracePeriodSeconds,
    podSpec=root.podSpec,
  ):: {
    local labels = { app: name },
    local probe = if withoutProbe then {}
    else if std.objectHas(probes, 'livenessProbe') || std.objectHas(probes, 'readinessProbe') then probes
    else {
      livenessProbe: {
        tcpSocket: {
          port: port,
        },
        failureThreshold: 3,
        initialDelaySeconds: 360,
        periodSeconds: 10,
        successThreshold: 1,
      },
      readinessProbe: {
        tcpSocket: {
          port: port,
        },
        failureThreshold: 80,
        initialDelaySeconds: 5,
        periodSeconds: 5,
        successThreshold: 1,
      },
    },
    local vols = if std.length(volumes) > 0 then
      {
        volumes: volumes,
      } else {},
    local graceShutdown = if std.length(std.toString(terminationGracePeriodSeconds)) > 0 then
      {
        terminationGracePeriodSeconds: terminationGracePeriodSeconds,
      } else {},
    local colocatedSelector = {
      labelSelector: {
        matchExpressions: [{
          key: 'app',
          operator: 'In',
          values: [name],
        }],
      },
      topologyKey: 'kubernetes.io/hostname',
    },
    local affinity = if neverColocated then {
      affinity: {
        podAntiAffinity: {
          requiredDuringSchedulingIgnoredDuringExecution: [colocatedSelector],
        },
      },
    } else {
      affinity: {
        podAntiAffinity: {
          preferredDuringSchedulingIgnoredDuringExecution: [{
            weight: 100,
            podAffinityTerm: colocatedSelector,
          }],
        },
      },
    },
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      namespace: namespace,
      name: name,
      labels: labels,
    },
    spec: {
      replicas: replicas,
      strategy: {
        rollingUpdate: {
          maxSurge: maxSurge,
          maxUnavailable: 0,
        },
        type: 'RollingUpdate',
      },
      selector: {
        matchLabels: labels,
      },
      template: {
        metadata: {
          labels: labels,
        },
        spec: {
          containers: [
            {
              name: name,
              image: resolve_image(namespace, name, image),
              imagePullPolicy: 'IfNotPresent',
              ports: [
                {
                  name: 'app',
                  containerPort: port,
                },
              ],
              resources: {
                limits: {
                  cpu: cpuLimit,
                  memory: memoryLimit,
                },
                requests: {
                  cpu: cpuRequest,
                  memory: memoryRequest,
                },
              },
            } + probe + configmapref(configmap) + envRef(envmap, env) + container,
          ],
        } + affinity + vols + imagePullSecretsRef(imagePullSecrets) + podSpec + graceShutdown,
      },
    },
  },

  pdb(namespace=root.defaultNamespace, name, minAvailable=root.minAvailable):: {
    apiVersion: 'policy/v1',
    kind: 'PodDisruptionBudget',
    metadata: {
      namespace: namespace,
      name: name,
    },
    spec: {
      minAvailable: minAvailable,
      selector: {
        matchLabels: { app: name },
      },
    },
  },

  hpa(namespace, name, minReplicas, maxReplicas, targetCPUUtilizationPercentage):: {
    apiVersion: 'autoscaling/v1',
    kind: 'HorizontalPodAutoscaler',
    metadata: {
      namespace: namespace,
      name: name,
    },
    spec: {
      scaleTargetRef: {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        name: name,
      },
      minReplicas: minReplicas,
      maxReplicas: maxReplicas,
      targetCPUUtilizationPercentage: targetCPUUtilizationPercentage,
    },
  },

}
