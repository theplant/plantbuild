local dc = import 'dc.jsonnet';

local ndc = dc {
  dockerRegistry: 'hub.c.163.com',
};

ndc.go_build_dep_image('theplant/example')
