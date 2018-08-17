FROM golang
ARG GITHUB_TOKEN
ARG WORKDIR
WORKDIR $WORKDIR
COPY . .
RUN set -x && \
    git config --global url."https://$GITHUB_TOKEN:x-oauth-basic@github.com/".insteadOf "https://github.com/" && \
    go get -t -d -v ./...
