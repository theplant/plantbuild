local k8s = import 'k8s.jsonnet';
k8s.list([
  k8s.image_to_url(
    name='app1',
    image='nginx:123',
    podSpec={
      serviceAccountName: 'account1',
      restartPolicy: 'Always',
      priority: 10,
    },
  ),
  k8s.deployment(
    name='app2',
    image='nginx:123',
    podSpec={
      serviceAccountName: 'account2',
      restartPolicy: 'Always',
      priority: 10,
    },
  ),
])
