local cfg = import 'config.jsonnet';
cfg {
  local root = self,
  local fullimage(namespace, name) = root.with_registry('%s/%s:%s' % [namespace, name, root.version]),
  local resolve_image(namespace, name, image) = if std.length(image) == 0 then
    fullimage(namespace, name)
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
  local envRef(envmap) = if std.length(std.objectFields(envmap)) > 0 then
    {
      env: [
        {
          name: n,
          value: envmap[n],
        }
        for n in std.objectFields(envmap)
      ],
    } else {},

  configmap(
    namespace=root.defaultNamespace,
    name,
    deployment='',
    cronjob='',
    data,
    withoutVersion=false
  ):: {
    assert !(std.length(deployment) == 0 && std.length(cronjob) == 0) : 'deployment or cronjob required',
    local labels = if std.length(deployment) > 0 then
      { deployment: deployment }
    else if std.length(cronjob) > 0 then
      { cronjob: cronjob }
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
    container={},
  ):: {
    kind: 'CronJob',
    apiVersion: 'batch/v1beta1',

    metadata: {
      namespace: namespace,
      name: name,
      labels: {
        app: name,
      },
    },
    spec: {
      schedule: schedule,
      concurrencyPolicy: 'Allow',
      failedJobsHistoryLimit: 10,
      successfulJobsHistoryLimit: 5,
      jobTemplate: {
        metadata: {
          labels: {
            app: name,
          },
        },
        spec: {
          backoffLimit: 1,
          activeDeadlineSeconds: 30,
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
                } + configmapref(configmap) + envRef(envmap) + container,
              ],
            } + imagePullSecretsRef(imagePullSecrets),
          },
        },
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
      if std.length(data['.dockerconfigjson']) > 0 then
        'kubernetes.io/dockerconfigjson'
      else if std.length(data['ca.crt']) > 0 && std.length(data.token) > 0 then
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
    path='/',
    configmap='',
    replicas=1,
    imagePullSecrets=root.imagePullSecrets,
    image='',
    port=root.port,
    memoryLimit=root.memoryLimit,
    cpuLimit=root.cpuLimit,
    ingressAnnotations={},
    envmap={},
    container={},
    volumes=[],
  ):: {
    apiVersion: 'v1',
    kind: 'List',
    items: [
      root.deployment(
        namespace=namespace,
        name=name,
        image=image,
        port=port,
        configmap=configmap,
        replicas=replicas,
        imagePullSecrets=imagePullSecrets,
        memoryLimit=memoryLimit,
        cpuLimit=cpuLimit,
        envmap=envmap,
        container=container,
        volumes=volumes,
      ),
      root.svc(namespace, name, port),
      root.single_svc_ingress(
        namespace=namespace,
        name=name,
        port=port,
        host=host,
        path=path,
        annotations=ingressAnnotations,
      ),
    ],
  },

  svc(namespace=root.defaultNamespace, name, port=root.port):: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: name,
      namespace: namespace,
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
          targetPort: port,
        },
      ],
      selector: {
        app: name,
      },
    },
  },

  single_svc_ingress(namespace=root.defaultNamespace, name, port, host='', path='/', annotations={})::
    local newhost = if std.type(host) != 'array' && std.length(host) == 0 && std.length(root.baseHost) > 0 then '%s.%s' % [name, root.baseHost] else host;
    local hosts = if std.type(host) == 'array' then host else [newhost];
    local rules = [
      {
        host: h,
        http: {
          paths: [
            {
              path: path,
              backend: {
                serviceName: name,
                servicePort: port,
              },
            },
          ],
        },
      }
      for h in hosts
    ];
    root.ingress(namespace, name, rules),

  ingress(namespace=root.defaultNamespace, name, rules, annotations={}):: {
    apiVersion: 'extensions/v1beta1',
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
      rules: rules,
    },
  },

  deployment(
    namespace=root.defaultNamespace,
    name,
    configmap='',
    envmap={},
    replicas=root.replicas,
    imagePullSecrets=root.imagePullSecrets,
    image='',
    port=root.port,
    withoutProbe=false,
    memoryLimit=root.memoryLimit,
    cpuLimit=root.cpuLimit,
    container={},
    volumes=[],
  ):: {
    local labels = { app: name },
    local probe = if withoutProbe then {} else {
      livenessProbe: {
        tcpSocket: {
          port: port,
        },
        initialDelaySeconds: 5,
        periodSeconds: 10,
      },
      readinessProbe: {
        tcpSocket: {
          port: port,
        },
        initialDelaySeconds: 5,
        periodSeconds: 10,
      },
    },
    local vols = if std.length(volumes) > 0 then
      {
        volumes: volumes,
      } else {},
    apiVersion: 'extensions/v1beta1',
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
          maxSurge: 1,
          maxUnavailable: 0,
        },
        type: 'RollingUpdate',
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
                  cpu: '10m',
                  memory: '10Mi',
                },
              },
            } + probe + configmapref(configmap) + envRef(envmap) + container,
          ],
        } + vols + imagePullSecretsRef(imagePullSecrets),
      },
    },
  },
}
