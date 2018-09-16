local k8s = import 'k8s.jsonnet';

k8s.list([
  k8s.deployment(
    namespace='example',
    name='cm-app1',
    configmap='',
    imagePullSecrets='',
  ),
  k8s.deployment(
    namespace='example',
    name='cm-app1',
    configmap='mycm',
    imagePullSecrets='myips',
    envmap={
      name1: 'value1',
    },
  ),
])
