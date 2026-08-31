## What is this

a command line tool to test, build, push docker images, write kubernetes configurations and deploy to kubernetes cluster. it heavily uses the fantastic [Jsonnet programming language](https://jsonnet.org)

It utilize a docker image published at `ghcr.io/theplant/plantbuild:latest`, This docker image includes:

- The jsonnet binary to execute jsonnet files to generate json output
- The image building, testing docker-compose and deploying kubernetes jsonnet template functions

## Install plantbuild command

```
sudo curl -fsSL https://raw.githubusercontent.com/theplant/plantbuild/master/plantbuild > /usr/local/bin/plantbuild && sudo chmod +x /usr/local/bin/plantbuild
```

## Vendoring the jsonnet libraries with jsonnet-bundler

By default plantbuild generates manifests by running jsonnet inside the
`ghcr.io/theplant/plantbuild` image, using the `jsonnetlib` baked into that image.

Alternatively a project can pin the libraries itself with
[jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler). Put a
`jsonnetfile.json` in the root of your project:

```json
{
  "version": 1,
  "dependencies": [
    {
      "source": {
        "git": {
          "remote": "https://github.com/theplant/plantbuild.git",
          "subdir": "jsonnetlib"
        }
      },
      "version": "master"
    }
  ],
  "legacyImports": true
}
```

When plantbuild finds a `jsonnetfile.json` in the current directory it will:

- download `jb` and `jsonnet` if they are not already on `PATH` (into a temp directory that
  is removed on exit, so a fresh CI container needs no preinstalled toolchain)
- run `jb install` to populate `vendor/`
- generate manifests locally with `jsonnet -J vendor/jsonnetlib/ -J vendor/ -V VERSION=...`
  instead of running the docker image

`imports` keep working unchanged (`import 'k8s.jsonnet'`), and transitive dependencies of
`jsonnetlib` (k8s-libsonnet, gateway-api-libsonnet, ...) resolve through `-J vendor/`.
Projects without a `jsonnetfile.json` are unaffected and keep using the docker image.

The downloaded tool versions can be overridden with the `JB_VERSION` and `JSONNET_VERSION`
environment variables.

## Command Manual

plantbuild -- Test, Build, Push images, and Deploy to kubernetes cluster

#### Display generated configuration json content

show docker-compose image build file

```
plantbuild show ./example/build.jsonnet -v 1.0.0
```

show k8s deploy file

```
plantbuild show ./example/deploy.jsonnet -v 1.0.0
```

#### Run with docker-compose

Runs the `<app>_test` service of the given docker-compose jsonnet, for example one
written with `dc.node_apps_test`.

```
plantbuild run ./test.jsonnet -v 1.0.0 -a app1
```

#### Build and push images

only build image locally

```
plantbuild build ./example/build.jsonnet -v 1.0.1 -a app1
```

push includes build as a prestep

```
plantbuild push ./example/build.jsonnet -v 1.0.1 -a app1
```

#### Deploy to Kubernetes cluster

```
plantbuild k8s_apply ./example/k8s/all.jsonnet
```

#### Deploy a configmap and patch the corresponding deployment or cronjob that uses the configmap

```
plantbuild k8s_cm_patch ./exmaple/k8s/cm-app1.jsonnet
plantbuild k8s_cm_patch ./exmaple/k8s/cm-cronjob1.jsonnet
```

#### Deploy to a Remote Kubernetes Cluster behind bastion

```
export KUBECTL_BASH="ssh admin@bastion.server.address /bin/bash"
plantbuild k8s_apply ./example/k8s/all.jsonnet
```

## How to write Docker Compose and Kubernetes config file with jsonnet


The source code located inside jsonnetlib/dc.jsonnet which is for generate docker-compose files, jsonnetlib/k8s.jsonnet which is for generate k8s config files.

You write this in your projects

build.jsonnet:

```
local dc = import 'dc.jsonnet';

dc.build_apps_image("theplant/example", ["app1", "app2"])

```

It first import the library dc.jsonnet from theplant/plantbuild docker image,
And then it config the apps of the project that needs images, and the function `dc.build_apps_image` generate a valid docker-compose file for you to build those images, You can run this to checkout the output docker-compose file content

```
docker run --rm -e VERSION=1.2.0 -e RUN=/src/build.jsonnet -v `pwd`/example:/src ghcr.io/theplant/plantbuild
```

Then `plantbuild` command wraps the above commands gives you a short way of invoking the command. simplify the above command to:

```
plantbuild show ./build.jsonnet
```

## How to overwrite default configurations of the provided templates

```jsonnet

local k8s = import 'k8s.jsonnet'

local myk8s = k8s + {
  dockerRegistry: 'registry.mydomain.com',
  imagePullSecrets: 'my-secrets',
  namespace: 'mynamespace',
  port: 4000,
  baseHost: 'myserver.com',
  memoryRequest='40Mi',
  cpuRequest='100m',
  memoryLimit: '200Mi',
  cpuLimit: '500m',
  replicas: 1,
}


myk8s.list([
    myk8s.image_to_url(
        name='myapp1',
        image='nginx',
        configmap='myapp1-cm',
    ), // This will use the "nginx:latest" image, and namespace will be default to "mynamespace" as above configured.

    myk8s.configmap(
        name='myapp1-cm',
        withoutVersion=true,
        data={
            name1: 'value1',
        },
    ),

    myk8s.image_to_url(
        namespace='theplant',
        name='myapp2',
        host='myapp2.myserver.com',
    ), // This will use image "registry.mydomain.com/theplant/myapp1:dce1f3a" like image url

    myk8s.cronjob(
        name='cronjob1',
        schedule='* * * * *',
        envmap={
            HelloName: 'Felix',
        },
        container={
            image: 'alpine',
            args: [
            '/bin/sh',
            '-c',
            'echo "Hello world $HelloName"',
            ],
        },
    ),
])

```


## Reference

A list of functions inside the library:

###  Kubernetes functions

- k8s.image_to_url
- k8s.deployment
- k8s.svc
- k8s.ingress
- k8s.cronjob
- k8s.configmap
- k8s.list

###  Docker Compose functions

- dc.node_apps_test
- dc.build_image
- dc.build_apps_image

Checkout [Examples](https://github.com/theplant/plantbuild/tree/master/example) for usage


## Develop

### Testing

```
bash test.sh
bash test_with_kubectl.sh
```

