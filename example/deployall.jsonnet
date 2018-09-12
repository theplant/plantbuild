local k8s = import 'k8s.jsonnet';

k8s.list([
  import './deploy.jsonnet',
  k8s.image_to_url(
    namespace='example',
    name='app2',
    host='app2.example.theplant-dev.com',
    path='/',
    configmap='cm-example',
  ),
  k8s.deployment(
    namespace='example',
    name='app3',
    configmap='cm-example',
    withoutProbe=true,
    cpuLimit='1000m',
    memoryLimit='1000Mi',
  ),
])
