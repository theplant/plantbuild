local k8s = import 'k8s.jsonnet';

k8s.image_to_url(
  name='app1',
  image='nginx:123',
  container={
    volumeMounts: [
      {
        name: 'ssl',
        readOnly: true,
        mountPath: '/etc/nginx/ssl',
      },
    ],
  },
  volumes=[
    {
      name: 'ssl',
      secret: {
        secretName: 'mysecret',
      },
    },
  ],
)
