// For section a
local k8s = import 'k8s.jsonnet';

k8s.configmap(
  namespace='example',
  name='cm-cronjob1',
  cronjob='cronjob1',
  data={
    HelloName: 'Felix1',
  }
)
