#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

# vendor/ holds jsonnet-bundler dependencies, they are not ours to format
if ! find . -name vendor -prune -o -name '*.jsonnet' -exec jsonnetfmt --test '{}' +
then
  echo "ERROR: found unformatted jsonnet files. Fix with plantbuild fmt-update"
  exit 1
fi