local k8s = import 'k8s.jsonnet';

k8s.deployment(
  namespace='prod-aigle',
  name='prod-aiglesubscriber',
  image='registry.theplant-dev.com/aigle/aiglesubscriber:ccc0e2',
  configmap='prod-aiglesubscriber-cm-latest',
  withoutProbe=true,
  replicas=3,
)
