#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

find . -name '*.jsonnet' -exec jsonnetfmt -i '{}' +
