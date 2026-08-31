local cfg = import 'config.jsonnet';
cfg {
  local root = self,
  local image_path(pkg, app, version) =
    local reg_ns = std.split(pkg, '/')[1];
    root.with_registry('%s/%s:%s' % [reg_ns, app, version])
  ,
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

}
