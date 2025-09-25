#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

if ! find . -name '*.jsonnet' -exec jsonnetfmt --test '{}' +
then
  echo "ERROR: found unformatted jsonnet files. Fix with plantbuild fmt-update"
  exit 1
fi