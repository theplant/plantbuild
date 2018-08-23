local dc = import 'dc.jsonnet';

dc.build_apps_image('theplant/example', ['app1', 'app2'])
