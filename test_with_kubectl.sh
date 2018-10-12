#!/bin/bash

./plantbuild k8s_apply ./example/k8s/tests/test_tricky_configmap.jsonnet
actual=$(kubectl get cm cm-tricky -o json | jq -r '.data.MoreTricky')
expected=$(./plantbuild show ./example/k8s/tests/test_tricky_configmap.jsonnet | jq -r '.data.MoreTricky')
diff -B <(printf $actual) <(printf $expected) || (echo "FAILED" && exit 1)
