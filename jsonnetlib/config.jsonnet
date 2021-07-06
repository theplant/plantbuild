local v = std.extVar('VERSION');
assert std.length(v) > 0 : 'version is empty';

{
  version: v,
  dockerRegistry: 'registry.example.com',
  imagePullSecrets: '',
  defaultNamespace: 'default',
  port: 4000,
  baseHost: '',
  memoryRequest: '20Mi',
  cpuRequest: '10m',
  memoryLimit: '200Mi',
  cpuLimit: '100m',
  maxSurge: 1,
  replicas: 1,
  minAvailable: 1,
  failedJobsHistoryLimit: 2,
  successfulJobsHistoryLimit: 1,
  projectRoot: '/go/src/github.com',
  podSpec: {},
  terminationGracePeriodSeconds: 30,

  // config helper func
  local root = self,
  with_registry(image)::
    if std.length(root.dockerRegistry) == 0 then
      image
    else
      '%s/%s' % [self.dockerRegistry, image],
}
