ARG JSONNET_VERSION=v0.22.0

FROM alpine:3.22
ARG JSONNET_VERSION
# Set by BuildKit to the architecture of the image, for example amd64.
ARG TARGETARCH
RUN apk add --no-cache ca-certificates
# The go-jsonnet release binaries are statically linked, so they run on
# Alpine. Download them in place of a compile with Go to build faster.
RUN set -eu; \
    url=https://github.com/google/go-jsonnet/releases/download/${JSONNET_VERSION}; \
    file=go-jsonnet_${JSONNET_VERSION#v}_linux_${TARGETARCH}.tar.gz; \
    cd /tmp; \
    wget -q "$url/$file" "$url/checksums.txt"; \
    grep "  $file\$" checksums.txt | sha256sum -c -; \
    tar -xzof "$file" -C /usr/local/bin jsonnet jsonnetfmt; \
    rm "$file" checksums.txt

ENV JSONNET_PATH=/jsonnetlib
ADD ./jsonnetlib /jsonnetlib
ADD entry.sh /entry.sh
ADD fmt-check.sh /fmt-check.sh
ADD fmt-update.sh /fmt-update.sh
RUN chmod +x /entry.sh /fmt-check.sh /fmt-update.sh

ENTRYPOINT ["/entry.sh"]