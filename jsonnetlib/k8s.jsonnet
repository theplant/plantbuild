{
  local root = self,
  local version = import 'version.jsonnet',
  local fullimage(namespace, name) = 'registry.theplant-dev.com/%s/%s:%s' % [namespace, name, version],
  local defaultImagePullSecrets = 'theplant-registry-secrets',

  list(items)::
    local make_items(items) = if std.type(items) == "array" then
            [make_items(it) for it in items]
        else if std.type(items) == "object" && items.kind == 'List' then
            items.items
        else
            [items];
    {apiVersion: "v1"} +
    {kind: "List"} +
    {items: std.flattenArrays(make_items(items))},

  image_to_url(
    namespace,
    name,
    host,
    path,
    configmap='',
    replicas=1,
    imagePullSecrets=defaultImagePullSecrets,
    image='',
    port=4000,
    memoryLimit="200Mi",
    cpuLimit='500m',
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
      ),
      root.svc(namespace, name, port),
      root.ingress(namespace, name, port, host, path),
    ],
  },

  svc(namespace, name, port):: {
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

  ingress(namespace, name, port, host, path='/'):: {
    apiVersion: 'extensions/v1beta1',
    kind: 'Ingress',
    metadata: {
      name: name,
      namespace: namespace,
      annotations: {
        'nginx.ingress.kubernetes.io/rewrite-target': '/',
      },
      labels: {
        app: name,
      },
    },
    spec: {
      rules: [
        {
          host: host,
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
        },
      ],
    },
  },

  deployment(
    namespace,
    name,
    configmap='',
    replicas=1,
    imagePullSecrets=defaultImagePullSecrets,
    image='',
    port=4000,
    withoutProbe=false,
    memoryLimit="200Mi",
    cpuLimit='500m',
  ):: {
    local labels = { app: name },

    local fimg = if std.length(image) == 0 then
      fullimage(namespace, name)
    else
      image,

    local cfgmap = if std.length(configmap) == 0 then
      'cm-%s' % name
    else
      configmap,

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
          imagePullSecrets: [
            {
              name: imagePullSecrets,
            },
          ],
          containers: [
            {
              name: name,
              image: fimg,
              imagePullPolicy: 'IfNotPresent',
              envFrom: [
                {
                  configMapRef: {
                    name: cfgmap,
                  },
                },
              ],
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
            } + if withoutProbe then {} else {
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
          ],
        },
      },
    },
  },
}
