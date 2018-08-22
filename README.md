## What is this

This docker image includes:

- The jsonnet binary to execute jsonnet files to generate json output
- The kubectl binary to be able to execute apply on semaphore ci given mount kube config as ~/.kube/config
- The Plant image building, testing docker-compose templates and deploying kubernetes templates

## Install plantbuild command

```
sudo curl -s https://raw.githubusercontent.com/theplant/plantbuild/master/plantbuild > /usr/local/bin/plantbuild && sudo chmod +x /usr/local/bin/plantbuild
```

## Command Manual

plantbuild -- Test, Build, Push images, and Deploy to kubernetes cluster

#### Display generated configuration json content

show test docker-compose file

```
plantbuild show ./example/test.jsonnet -v 1.0.0
```

show docker-compose image build file

```
plantbuild show ./example/build.jsonnet -v 1.0.0
```

show k8s deploy file

```
plantbuild show ./example/deploy.jsonnet -v 1.0.0
```

#### Run with docker-compose

```
plantbuild run ./example/test.jsonnet -v 1.0.0 -a app1
```

#### Build and push images

```
plantbuild push ./example/build.jsonnet -v 1.0.1 -a app1
```

## How to write Docker Compose and Kubernetes config file with jsonnet

The source code located inside jsonnetlib/dc.jsonnet which is for generate docker-compose files, jsonnetlib/k8s.jsonnet which is for generate k8s config files.

You write this in your projects

test.jsonnet:

```
local dc = import 'dc.jsonnet';

local modules = [
    "accounting",
    "inventory",
];

dc.go_test("theplant/example", modules, ["postgres", "elasticsearch", "nats", "redis"])

```

It first import the library dc.jsonnet from theplant/plantbuild docker image,
And then it config the modules the projects that needs to test, and the function `dc.go_test` generate a valid docker-compose file for you to run those tests, You can run this to checkout the output docker-compose file content

```
docker run --rm -e VERSION=1.2.0 -e RUN=/src/dc.test.jsonnet -v `pwd`/example:/src registry.theplant-dev.com/theplant/plantbuild

```

Then `plantbuild` command wraps the above commands gives you a short way of invoking the command.

A list of functions inside the library:

- dc.go_test
- dc.go_build_dep_image
- dc.build_app_image
- k8s.image2url
- k8s.deployment
- k8s.svc
- k8s.ingress
