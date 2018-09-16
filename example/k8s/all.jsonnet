local k8s = import 'k8s.jsonnet';

k8s.list([
  import './app1.jsonnet',
  k8s.image_to_url(
    namespace='example',
    name='app2',
    host='app2.example.theplant-dev.com',
    path='/',
    configmap='cm-example',
  ),
  k8s.deployment(
    namespace='example',
    name='app3',
    configmap='cm-example',
    withoutProbe=true,
    cpuLimit='1000m',
    memoryLimit='1000Mi',
  ),
  k8s.list([
    k8s.configmap(
      namespace='example',
      name='cm1',
      cronjob='cronjob2',
      withoutVersion=true,
      data={
        name1: 'value1',
      },
    ),
    k8s.list([
      k8s.configmap(
        namespace='example',
        name='cronjobcm2',
        withoutVersion=true,
        cronjob='cronjob1',
        data={
          cronjobenv2: 'value2',
        },
      ),
      k8s.cronjob(
        namespace='example',
        name='cronjob1',
        schedule='10 * * * *',
        envmap={
          cronjobenv1: 'value1',
        },
      ),
      k8s.cronjob(
        namespace='example',
        name='cronjob2',
        schedule='10 * * * *',
        image='sunfmin/echo:latest',
        configmap='cronjobcm2',
      ),
    ]),
  ]),
])
