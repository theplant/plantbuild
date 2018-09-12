// For section a
local k8s = import 'k8s.jsonnet';

k8s.configmap(
  namespace='test',
  name='hello',
  data={
    Hello: 'Value1',
    OwnerName: 'Felix',
    // For Section b
    Hello1: 'ABC',
  }
)
