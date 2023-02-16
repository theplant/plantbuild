local k8s = import 'k8s.jsonnet';

k8s.list([
  k8s.image_to_url(
    namespace='example',
    name='demo',
    host='demo.example.theplant-dev.com',
    path='/',
    withoutRollingUpdate=true
  ),
])
