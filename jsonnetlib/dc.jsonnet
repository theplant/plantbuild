{
    local root = self,
    local version = import 'version.jsonnet',

    go_test(pkg, modules, deps):: {
        local projectRoot = "/go/src/github.com/%s" % pkg,
        local image = "registry.theplant-dev.com/%s_dep:%s" % [pkg, version],

        version: "3",
        services: {
            ["%s_test" % m] : {
                image: image,
                volumes: [
                    ".:%s" % projectRoot,
                ],
                entrypoint: "go test -v -p=1 ./%s/..." % m,
                env_file: "./%s/test.env" % m,
                depends_on: deps,
            } for m in modules
        } + {
            [name] : root.deps[name] for name in deps
        },
    },

    go_build_dep_image(pkg):: {
        "version": "3",
        "services": {
            "dep_image": {
            "build": {
                "context": ".",
                "dockerfile": "./Dep.Dockerfile",
                "args": [
                    "GITHUB_TOKEN=$GITHUB_TOKEN",
                    "WORKDIR=/go/src/github.com/%s" % pkg
                ]
            },
            "image": "registry.theplant-dev.com/%s-dep:%s" % [pkg, version]
            }
        }
    },

    build_app_image(pkg, modules):: {
        "version": "3",
        "services": {
            ["build_image_%s" % m]: {
                "build": {
                    "context": ".",
                    "dockerfile": "./%s/Dockerfile" % m,
                    "args": [
                        "GITHUB_TOKEN=$GITHUB_TOKEN",
                        "NPM_TOKEN=$NPM_TOKEN",
                    ]
                },
            "image": "registry.theplant-dev.com/%s-%s:%s" % [pkg, m, version]
            }  for m in modules
        }
    },

    deps:: {
        "postgres": {
            "image": "postgres:9.6.6",
            "environment": [
                "POSTGRES_USER=ec",
                "POSTGRES_PASSWORD=123",
                "POSTGRES_DB=ec_test"
            ],
            "ports": [
                "5001:5432"
            ]
        },

        "elasticsearch": {
            "image": "registry.theplant-dev.com/ec/elasticsearch:5.5.0.2",
            "environment": [
                "ES_JAVA_OPTS=-Xms1g -Xmx1g"
            ],
            "entrypoint": [
                "/docker-entrypoint.sh",
                "-Ehttp.publish_host=127.0.0.1",
                "-Ehttp.publish_port=9250"
            ],
            "ports": [
                "9250:9200",
                "9350:9300"
            ]
        },

        "redis": {
            "image": "redis:4",
            "ports": [
                "6479:6379"
            ]
        },

        "nats": {
            "image": "nats",
            "entrypoint": "/gnatsd -DV",
            "ports": [
                "8222:8222",
                "4222:4222"
            ]
        }
    },
}
