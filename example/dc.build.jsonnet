local dc = import 'dc.jsonnet';

dc.build_app_image("theplant/example", "1.0.0", ["app1", "app2"])
