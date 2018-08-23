local k8s = import 'k8s.jsonnet';

k8s.image_to_url(
  namespace='example',
  name='app1',
  host='app1.example.theplant-dev.com',
  path='/',
  configmap='cm-example',
)
