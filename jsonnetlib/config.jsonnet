local v = std.extVar('VERSION');
assert std.length(v) > 0 : 'version is empty';

{
  version: v,
  dockerRegistry: 'registry.example.com',
  imagePullSecrets: '',
  defaultNamespace: 'default',
  port: 4000,
  baseHost: '',
  cronCPURequest: '50m',
  cronCPULimit: '500m',
  cronMemoryRequest: '20Mi',
  cronMemoryLimit: '2Gi',
  memoryRequest: '20Mi',
  cpuRequest: '5m',
  memoryLimit: '100Mi',
  cpuLimit: '50m',
  maxSurge: 1,
  replicas: 1,
  minAvailable: 1,
  failedJobsHistoryLimit: 1,
  successfulJobsHistoryLimit: 1,
  projectRoot: '/go/src/github.com',
  podSpec: {},
  cronjobSpec: {},
  terminationGracePeriodSeconds: 30,
  ingressClassName: 'nginx',
  pathType: 'ImplementationSpecific',
  jobTTL: 1800,
  cronjobTTL: 3600,

  // config helper func
  local root = self,
  with_registry(image)::
    if std.length(root.dockerRegistry) == 0 then
      image
    else
      '%s/%s' % [self.dockerRegistry, image],
}
