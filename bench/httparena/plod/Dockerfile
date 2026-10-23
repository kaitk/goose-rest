# Plod's HttpArena entry. bench/httparena.sh copies this directory into
# HttpArena's frameworks/plod/, with the package's *.goose under src/, and
# app.goose and the root files at src/bench/httparena/plod/, where they import
# the package from "../../../", and scripts/goose.sh beside them.
FROM ubuntu:26.04 AS build
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends ca-certificates curl git cmake ninja-build gcc g++ \
        liburing-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# The release scripts/goose.sh pins, or with GOOSE_COMMIT that commit built
# from source.
ARG GOOSE_COMMIT=
COPY src/scripts/goose.sh /src/scripts/goose.sh
RUN GOOSE_COMMIT="$GOOSE_COMMIT" /src/scripts/goose.sh >/goose-path

COPY src /src
# Two builds: without TLS, and with the TLS listeners, which links OpenSSL.
# Goose fetches goose-http and the packages the root files name.
RUN goose=$(cat /goose-path) && cd /src/bench/httparena/plod && \
    $goose build --cc gcc --standalone -o /server server.goose && \
    $goose build --cc gcc --standalone -o /server-tls server_tls.goose

FROM ubuntu:26.04
# goose-http links liburing on Linux, and the TLS build OpenSSL.
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends liburing2 libssl3t64 && \
    rm -rf /var/lib/apt/lists/*
COPY --from=build /server /server
COPY --from=build /server-tls /server-tls
EXPOSE 8080 8081 8082 8443
# The TLS build where HttpArena mounts the certificate at /certs, for the
# profiles that use it; the other otherwise. One worker per CPU of the
# container's cpuset, goose-http's default.
CMD ["/bin/sh", "-c", "if [ -r /certs/server.crt ] && [ -r /certs/server.key ]; then TLS_CERT=/certs/server.crt TLS_KEY=/certs/server.key exec /server-tls; fi; exec /server"]
