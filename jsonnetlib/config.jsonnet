local v = std.extVar('VERSION');
assert std.length(v) > 0 : 'version is empty';

{
  version: v,
  dockerRegistry: 'registry.theplant-dev.com',
  imagePullSecrets: 'theplant-registry-secrets',
  defaultNamespace: 'default',
  port: 4000,
  baseHost: '',
  memoryLimit: '200Mi',
  cpuLimit: '500m',
  replicas: 1,

  // config helper func
  local root = self,
  with_registry(image)::
    if std.length(root.dockerRegistry) == 0 then
      image
    else
      '%s/%s' % [self.dockerRegistry, image],
}
