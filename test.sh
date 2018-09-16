if which jsonnet; then
    echo "formatting code"
    find . -name '*.jsonnet' | xargs jsonnet fmt -i
fi

fail() {
    echo "FAILED:" $1
    exit 1
}

## Build
./plantbuild build ./build.jsonnet

## Tests
./plantbuild show ./example/build.jsonnet -v 1.0.0
diff -B <(./plantbuild show ./example/build.jsonnet -v 1.0.0 | jq -r '.services.build_image_app1.image') <(echo registry.theplant-dev.com/example/app1:1.0.0) || fail "./example/build.jsonnet image is wrong"

./plantbuild show ./example/dep.jsonnet -v 1.0.0
diff -B <(./plantbuild show ./example/dep.jsonnet -v 1.0.0 | jq -r '.services.build_image.image') <(echo hub.c.163.com/example/dep:1.0.0) || fail "./example/build.jsonnet image is wrong"

./plantbuild show ./example/test.jsonnet -v 1.0.0
diff -B <(./plantbuild show ./example/test.jsonnet -v 1.0.0 | jq -r '.services.accounting_test.entrypoint') <(echo 'go test -v -p=1 ./accounting/...') || fail "./example/build.jsonnet image is wrong"

./plantbuild show ./example/k8s/app1.jsonnet -v 1.0.0
diff -B <(./plantbuild show ./example/k8s/app1.jsonnet -v 1.0.0 | jq -r '.items[0].spec.template.spec.containers[0].image') <(echo 'registry.theplant-dev.com/example/app1:1.0.0') || fail "./example/k8s/app1.jsonnet image is wrong"

./plantbuild show ./example/k8s/all.jsonnet -v 2.1.0
ALL=$(./plantbuild show ./example/k8s/all.jsonnet -v 2.1.0)
diff -B <(echo $ALL | jq -r '.items[0].spec.template.spec.containers[0].image') <(echo 'registry.theplant-dev.com/example/app1:2.1.0') || fail "./example/k8s/app1.jsonnet image is wrong"
diff -B <(echo $ALL | jq -r '.items[].kind'|tr '\n' ,) <(echo -n 'Deployment,Service,Ingress,Deployment,Service,Ingress,Deployment,ConfigMap,ConfigMap,CronJob,CronJob,') || fail "./example/k8s/all.jsonnet List is wrong"

./plantbuild show ./example/k8s/tests/test_probe_cm.jsonnet
diff -B <(./plantbuild show ./example/k8s/tests/test_probe_cm.jsonnet | jq '.spec.template.spec.containers[0].livenessProbe') <(echo null) || fail "./example/k8s/tests/test_probe_cm.jsonnet probe is wrong"

./plantbuild show ./example/k8s/tests/test_multi_hosts.jsonnet
diff -B <(./plantbuild show ./example/k8s/tests/test_multi_hosts.jsonnet | jq -r '.items[2].spec.rules[].host' | tr '\n' ,) <(echo -n 'app1.example.theplant-dev.com,app1-1.example.theplant-dev.com,app1-2.example.theplant-dev.com,') || fail "./example/k8s/tests/test_probe_cm.jsonnet probe is wrong"
