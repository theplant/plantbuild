local cfg = import 'config.jsonnet';
cfg {
  local root = self,
  local image_path(pkg, app, version) =
    local reg_ns = std.split(pkg, '/')[1];
    root.with_registry('%s/%s:%s' % [reg_ns, app, version])
  ,
  local get_dep(name, customized_deps) =
    if std.objectHas(customized_deps, name) then
      customized_deps[name]
    else
      root.deps[name],

  go_apps_test(pkg, apps, deps=[], customized_deps={},):: {
    local to_obj(m) =
      local projectRoot = '%s/%s' % [root.projectRoot, pkg];
      local name = if std.type(m) == 'object' then
        m.name
      else
        m;

      local default = {
        mount: projectRoot,
        command: [
          'sh',
          '-c',
          'go get -t ./%s/... && go test -p=1 ./%s/...' % [name, name],
        ],
        test_env: './%s/test.env' % name,
      };

      if std.type(m) == 'object' then
        default + m
      else
        default { name: m },

    local image = image_path(pkg, 'dep', root.version),

    version: '3',
    services: {
      ['%s_test' % to_obj(m).name]: {
        image: image,
        volumes: [
          '.:%s' % to_obj(m).mount,
        ],
        command: to_obj(m).command,
        env_file: to_obj(m).test_env,
        depends_on: deps,
      }
      for m in apps
    } + {
      [name]: get_dep(name, customized_deps)
      for name in (deps)
    },
  },

  go_test(pkg, deps=[], customized_deps={},):: {
    local projectRoot = '%s/%s' % [root.projectRoot, pkg],
    local image = root.with_registry('%s-dep:%s' % [pkg, root.version]),
    version: '3',
    services: {
      test: {
        image: image,
        volumes: [
          '.:%s' % projectRoot,
        ],
        command: [
          'sh',
          '-c',
          'go get -t ./... && go test -p=1 ./...',
        ],
        env_file: './test.env',
        depends_on: deps,
      },
    } + {
      [name]: get_dep(name, customized_deps)
      for name in deps
    },
  },

  node_apps_test(apps):: {
    version: '3',
    services: {
      ['%s_test' % m]: {
        build: {
          context: './%s' % m,
          dockerfile: './Test.Dockerfile',
          args: [
            'NPM_TOKEN=$NPM_TOKEN',
          ],
        },
        entrypoint: 'yarn ci',
      }
      for m in apps
    },
  },

  go_build_dep_image(pkg, for_multiple_apps=true):: {
    version: '3',
    services: {
      build_image: {
        build: {
          context: '.',
          dockerfile: './Dep.Dockerfile',
          args: [
            'GITHUB_TOKEN=$GITHUB_TOKEN',
            'WORKDIR=%s/%s' % [root.projectRoot, pkg],
          ],
        },
        image: if for_multiple_apps then image_path(pkg, 'dep', root.version) else root.with_registry('%s-dep:%s' % [pkg, root.version]),
      },
    },
  },

  build_apps_image(pkg, apps):: {
    local to_obj(m) =
      local name = if std.type(m) == 'object' then
        m.name
      else
        m;
      local default = {
        name: name,
        dockerfile: './%s/Dockerfile' % name,
        context: '.',
      };

      if std.type(m) == 'object' then
        default + m
      else
        default,

    version: '3',
    services: {

      ['build_image_%s' % to_obj(m).name]: {
        build: {
          context: to_obj(m).context,
          dockerfile: to_obj(m).dockerfile,
          args: [
            'GITHUB_TOKEN=$GITHUB_TOKEN',
            'NPM_TOKEN=$NPM_TOKEN',
          ],
        },
        image: image_path(pkg, to_obj(m).name, root.version),
      }
      for m in apps
    },
  },

  build_image(pkg):: {
    version: '3',
    services: {
      build_image: {
        build: {
          context: '.',
          dockerfile: './Dockerfile',
          args: [
            'GITHUB_TOKEN=$GITHUB_TOKEN',
            'NPM_TOKEN=$NPM_TOKEN',
          ],
        },
        image: root.with_registry('%s:%s' % [pkg, root.version]),
      },
    },
  },

  deps:: {
    postgres: {
      image: 'postgres:9',
      environment: [
        'POSTGRES_USER=db',
        'POSTGRES_PASSWORD=123',
        'POSTGRES_DB=db_test',
      ],
      ports: [
        '5001:5432',
      ],
    },

    elasticsearch: {
      image: 'theplant/elasticsearch:5.5.0.2',
      environment: [
        'ES_JAVA_OPTS=-Xms1g -Xmx5g',
      ],
      entrypoint: [
        '/docker-entrypoint.sh',
        '-Ehttp.publish_host=127.0.0.1',
        '-Ehttp.publish_port=9250',
      ],
      ports: [
        '9250:9200',
        '9350:9300',
      ],
    },

    redis: {
      image: 'redis:4',
      ports: [
        '6479:6379',
      ],
    },

    nats: {
      image: 'nats',
      entrypoint: '/gnatsd -DV',
      ports: [
        '8222:8222',
        '4222:4222',
      ],
    },

    influxdb: {
      image: 'influxdb:1.5',
      ports: [
        '8085:8086',
      ],
    },
  },
}
