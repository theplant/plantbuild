local k8s = import 'k8s.jsonnet';

k8s.image_to_url(
  namespace='example',
  name='demo',
  host='demo.example.theplant-dev.com',
  path='/',
  configmap='cm-app1-latest',
  minReplicas=2,
  maxReplicas=5,
  targetCPUUtilizationPercentage=70,
  memoryRequest='40Mi',
  cpuRequest='100m',
  memoryLimit='8G',
  cpuLimit='1500m',
  ingressTLSEnabled=true,
  ingressAnnotations={
    'kubernetes.io/ingress.class': 'nginx',
    'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
    'kubernetes.io/tls-acme': 'true',
    'certmanager.k8s.io/cluster-issuer': 'letsencrypt',
  },
)
