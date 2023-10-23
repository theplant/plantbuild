local dc = import 'dc.jsonnet';
local ndc = dc {
  dockerRegistry: 'ghcr.io',
};
ndc.build_image('theplant/plantbuild')
