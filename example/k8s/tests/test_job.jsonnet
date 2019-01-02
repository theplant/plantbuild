local k8s = import 'k8s.jsonnet';

k8s.job(
  namespace='default',
  name='pi',
  image='perl:5',
  configmap='cm-pi-latest',
  container={
    command: ['perl', '-Mbignum=bpi', '-wle', 'print bpi(2000)'],
  }
)
