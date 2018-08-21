## What is this

This docker image includes:

- The jsonnet binary to execute jsonnet files to generate json output
- The kubectl binary to be able to execute apply on semaphore ci given mount kube config as ~/.kube/config
- The Plant image building, testing docker-compose templates and deploying kubernetes templates

## Install plantbuild command

```
sudo curl -s https://raw.githubusercontent.com/theplant/plantbuild/master/plantbuild > /usr/local/bin/plantbuild && sudo chmod +x /usr/local/bin/plantbuild
```

## Docker Compose and Kubernetes config file generate functions

The source code located inside jsonnetlib/dc.jsonnet which is for generate docker-compose files, jsonnetlib/k8s.jsonnet which is for generate k8s config files.

### The Testing

```
local dc = import 'dc.jsonnet';

local modules = [
    "accounting",
    "inventory",
];

dc.test("theplant/example", "1.0.0", modules, ["postgres", "elasticsearch", "nats", "redis"])

```
It first import the library dc.jsonnet from theplant/plantbuild docker image,
And then it config the modules the projects that needs to test, and the function `dc.test` generate a valid docker-compose file for you to run those tests, You can run this to checkout the output docker-compose file content

```
docker run --rm -e VERSION=1.2.0 -e RUN=/src/dc.test.jsonnet -v `pwd`/example:/src registry.theplant-dev.com/theplant/plantbuild

```

## Getting Started


Copy files in example into your project root

To Build the dependency docker image

```go
docker run --rm -e VERSION=1.2.0 -e RUN=/src/dc.dep.jsonnet -v `pwd`/ci:/src registry.theplant-dev.com/theplant/plantbuild | docker-compose --verbose -f - build --no-cache
```

To Run tests of a certain module

```go
docker run --rm -e VERSION=1.2.0 -e RUN=/src/dc.test.jsonnet -v `pwd`/ci:/src registry.theplant-dev.com/theplant/plantbuild | docker-compose -f - run --rm inventory_test
```

To Build app image

```go
docker run --rm -e VERSION=1.2.0 -e RUN=/src/dc.build.jsonnet -v `pwd`/ci:/src registry.theplant-dev.com/theplant/plantbuild | docker-compose --verbose -f - build --no-cache
```
