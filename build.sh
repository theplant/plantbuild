#!/bin/bash

echo $GHCR_TOKEN | docker login ghcr.io --username theplant-ci --password-stdin

./plantbuild push build.jsonnet
