FROM bitnami/jsonnet:0.18.0
ADD ./jsonnetlib /jsonnetlib
ADD entry.sh /entry.sh
ENTRYPOINT /entry.sh
