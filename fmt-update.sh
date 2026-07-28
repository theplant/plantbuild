#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# vendor/ holds jsonnet-bundler dependencies, they are not ours to format
find . -name vendor -prune -o -name '*.jsonnet' -exec jsonnetfmt -i '{}' +