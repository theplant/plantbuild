if which jsonnet; then
    echo "formatting code"
    find . -name '*.jsonnet' | xargs jsonnet fmt -i
fi

./plantbuild build ./build.jsonnet && \
./plantbuild show ./example/build.jsonnet -v 1.0.0 && \
./plantbuild show ./example/dep.jsonnet -v 1.0.0 && \
./plantbuild show ./example/test.jsonnet -v 1.0.0 && \
./plantbuild show ./example/k8s/app1.jsonnet -v 1.0.0 && \
./plantbuild show ./example/k8s/all.jsonnet && \
./plantbuild show ./example/k8s/cm-app1.jsonnet && \
./plantbuild show ./example/k8s/test_probe_cm.jsonnet && \
./plantbuild show ./example/k8s/test_multi_hosts.jsonnet
