local k8s = import 'k8s.jsonnet';

k8s.image_to_url(
  namespace='dev-example',
  name='app1',
  image='registry.theplant-dev.com/example/app1',
  path='/',
)
