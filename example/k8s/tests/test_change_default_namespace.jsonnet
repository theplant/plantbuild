local k8s = import 'k8s.jsonnet';

local nk8s = k8s {
  namespace: 'myexample2',
  baseHost: 'dt.theplant-dev.com',
};

nk8s.list([
  nk8s.cronjob(
    name='hello',
    schedule='* * * * *',
  ),
  nk8s.configmap(
    name='cm',
    withoutVersion=true,
    deployment='dep1',
    data={
      name1: 'value1',
    },
  ),
  nk8s.deployment(
    name='dep1',
  ),
  nk8s.image_to_url(
    name='dep2',
  ),
])
