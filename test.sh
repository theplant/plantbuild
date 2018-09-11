./plantbuild build ./build.jsonnet && \
./plantbuild show ./example/build.jsonnet -v 1.0.0 && \
./plantbuild show ./example/dep.jsonnet -v 1.0.0 && \
./plantbuild show ./example/deploy.jsonnet -v 1.0.0 && \
./plantbuild show ./example/test.jsonnet -v 1.0.0 && \
./plantbuild show ./example/deployall.jsonnet && \
./plantbuild show ./example/patch_env.jsonnet && \
./plantbuild show ./example/patch_image.jsonnet
