local k8s = import 'k8s.jsonnet';

k8s.cronjob(
  namespace='example',
  name='cronjob1',
  configmap='cm-cronjob1-latest',
  schedule='* * * * *',
  container={
    image: 'alpine',
    args: [
      '/bin/sh',
      '-c',
      'echo "Hello world $HelloName"',
    ],
  },
)
