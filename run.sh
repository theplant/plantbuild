#!/bin/bash

function build_dep {
    docker run --rm -it -v `pwd`:/src registry.theplant-dev.com/theplant/jsonnet /src/dc.dep.jsonnet | docker-compose --verbose -f - build --no-cache
}

function test {
    docker run --rm -it -v `pwd`:/src registry.theplant-dev.com/theplant/jsonnet /src/dc.test.jsonnet | docker-compose -f - run --rm inventory_test
}

eval $1
