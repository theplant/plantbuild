// For section a
local k8s = import 'k8s.jsonnet';

k8s.patch_deployment_env({
    Hello: 'Value1',
    OwnerName: 'Felix',
    // For Section b
    Hello1: 'ABC',
})
