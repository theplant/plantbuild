ARG GO_VERSION=1.22
ARG JSONNET_VERSION=v0.18.0

# ---- builder: compile jsonnet + jsonnetfmt ----
FROM golang:${GO_VERSION}-alpine AS jsonnet-builder
ARG JSONNET_VERSION
RUN apk add --no-cache git
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go install github.com/google/go-jsonnet/cmd/jsonnet@${JSONNET_VERSION} && \
    go install github.com/google/go-jsonnet/cmd/jsonnetfmt@${JSONNET_VERSION}

# ---- runtime: Alpine 3.15.4 ----
FROM alpine:3.15.4
RUN apk add --no-cache ca-certificates
COPY --from=jsonnet-builder /go/bin/jsonnet /usr/local/bin/jsonnet
COPY --from=jsonnet-builder /go/bin/jsonnetfmt /usr/local/bin/jsonnetfmt

ENV JSONNET_PATH=/jsonnetlib
ADD ./jsonnetlib /jsonnetlib
ADD entry.sh /entry.sh
ADD fmt-verify.sh /fmt-verify.sh
ADD fmt-update.sh /fmt-update.sh
RUN chmod +x /entry.sh /fmt-verify.sh /fmt-update.sh

ENTRYPOINT ["/entry.sh"]