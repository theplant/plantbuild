FROM mexisme/jsonnet
ADD ./jsonnetlib /jsonnetlib
ENTRYPOINT [ "/jsonnet", "-J", "/jsonnetlib" ]
