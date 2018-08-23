local dc = import 'dc.jsonnet';

local ndc = dc {
    docker_registry: "hub.c.163.com",
};

ndc.go_build_dep_image('theplant/example')
