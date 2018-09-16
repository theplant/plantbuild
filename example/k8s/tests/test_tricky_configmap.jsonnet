// For section a
local k8s = import 'k8s.jsonnet';

k8s.configmap(
  namespace='default',
  name='cm-tricky',
  deployment='app1',
  withoutVersion=true,
  data={
    Hello: |||
      Value122'abc'
      &amp;"hello"
    |||,
    MoreTricky: "'Value122'abc&amp;\"hello\"'",
  }
)
