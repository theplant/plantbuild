local k8s = import 'k8s.jsonnet';

k8s.list([
  k8s.namespace(
    name='test',
  ),
  k8s.secret(
    namespace='test',
    name='theplant-registry-secrets',
    data={
      '.dockerconfigjson': 'eyJhdXRocyI6eyJyZWdpc3RyeS50aGVwbGFudC1kZXYuY29tIjp7InVzZXJuYW1lIjoieHh4IiwicGFzc3dvcmQiOiJ4eHgiLCJlbWFpbCI6Inh4eEBnbWFpbC5jb20iLCJhdXRoIjoiZUhoNE9uaDRlQT09In19fQ==',
    },
  ),
])
