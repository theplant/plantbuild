#!/bin/bash

echo $GHCR_TOKEN | docker login ghcr.io --username bohrasd --password-stdin

./plantbuild push build.jsonnet
