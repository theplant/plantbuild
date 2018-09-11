// For section a
local k8s = import 'k8s.jsonnet';

k8s.patch_deployment_image(
  namespace='example',
  name='app1',
)
