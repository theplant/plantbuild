local k8s = import 'k8s.jsonnet';
k8s.list([
  k8s.image_to_url(
    name='app1',
    image='nginx:123',
    lifecycle={
      lifecycle: {
        preStop: {
          exec: {
            command: [
              '/bin/sh',
              '-c',
              'kill -15 -1',
            ],
          },
        },
      },
    },
  ),
  k8s.deployment(
    name='app2',
    image='nginx:123',
    lifecycle={
      lifecycle: {
        preStop: {
          exec: {
            command: [
              '/bin/sh',
              '-c',
              'kill -15 -1',
            ],
          },
        },
      },
    },
  ),
])
