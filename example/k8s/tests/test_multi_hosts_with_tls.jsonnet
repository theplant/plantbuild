local k8s = import 'k8s.jsonnet';

k8s.image_to_url(
  namespace='example',
  name='app1',
  host=['app1.example.theplant-dev.com', 'app1-1.example.theplant-dev.com', 'app1-2.example.theplant-dev.com'],
  path='/',
  configmap='cm-app1-latest',
  ingressTLSEnabled=true,
  ingressAnnotations={
    'kubernetes.io/ingress.class': 'nginx',
    'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
    'kubernetes.io/tls-acme': 'true',
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
)
