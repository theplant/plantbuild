#!/usr/bin/env sh

jsonnet -J /jsonnetlib -V VERSION="$VERSION" "$RUN"
