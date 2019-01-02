// For section a
local k8s = import 'k8s.jsonnet';

k8s.configmap(
  namespace='default',
  name='cm-pi',
  job='pi',
  data={
    Hello: 'Value122',
  }
)
