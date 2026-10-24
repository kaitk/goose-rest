# A container to run bench/httparena.sh in where the shell can't reach Docker's
# host network: WSL under Docker Desktop, or macOS (bench/README.md). It holds
# HttpArena's harness's tools and Docker's client, which drives the host's
# Docker through its socket.
FROM docker:29.8.2-cli AS cli
FROM ubuntu:26.04
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    bash ca-certificates curl git jq python3 openssl util-linux procps bc nghttp2-client && \
    rm -rf /var/lib/apt/lists/*
COPY --from=cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins
