local dc = import 'dc.jsonnet';
local ndc = dc {
  dockerRegistry: 'public.ecr.aws',
};
ndc.build_image('theplant/plantbuild')
