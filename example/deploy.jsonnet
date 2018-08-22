local k8s = import 'k8s.jsonnet';

k8s.image2url(
  namespace='theplant',
  name='example',
  host='example.theplant-dev.com',
  path='/',
  configmap='cm-example',
)
