local k8s = import 'k8s.jsonnet';

k8s.list([
  k8s.deployment(
    namespace='example',
    name='demo',
    image='nginx:stable-alpine',
    configmap='',
    imagePullSecrets='',
    withoutProbe=true,
  ),
  k8s.hpa(
    namespace='example',
    name='demo',
    minReplicas=2,
    maxReplicas=5,
    targetCPUUtilizationPercentage=75
  ),
])
