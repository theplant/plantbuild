local modules = [
  'inventory',
];

local dc = import 'dc.jsonnet';

local otherdeps = {
  elasticsearch2: {
    entrypoint: [
      '/docker-entrypoint.sh',
      '-Ehttp.publish_host=127.0.0.1',
      '-Ehttp.publish_port=9251',
    ],
    environment: [
      'ES_JAVA_OPTS=-Xms1g -Xmx1g',
    ],
    image: 'registry.example.com/ec/elasticsearch:5.5.0.2',
    ports: [
      '9251:9200',
      '9351:9300',
    ],
  },
};

dc.go_apps_test('theplant/example', modules, ['postgres', 'elasticsearch2'], otherdeps)
