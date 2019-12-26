local k8s = import 'k8s.jsonnet';

k8s.set_images(
  namespace='demo-mcd-services',
  images=[
    { type: 'deployment', name: 'mop-catalogue-api', image: '123055475123.dkr.ecr.ap-northeast-1.amazonaws.com/mcd-services/catalogue-api' },
    { type: 'cronjob', name: 'mop-catalogue-api', image: '123055475123.dkr.ecr.ap-northeast-1.amazonaws.com/mcd-services/catalogue-api' },
    { type: 'job', name: 'mop-catalogue-api', image: '123055475123.dkr.ecr.ap-northeast-1.amazonaws.com/mcd-services/catalogue-api' },
  ],
)
