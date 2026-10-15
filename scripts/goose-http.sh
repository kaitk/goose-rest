#!/bin/sh
# Sourced by the benchmark scripts, after they set root: sets and exports
# GOOSE_HTTP, a goose-http checkout for its benchmark scripts and datasets
# (bench/README.md), the first of:
#
#   GOOSE_HTTP   already set: the checkout as given
#   (unset)      a clone of kaitk/goose-http at the pin rest.goose imports,
#                which the first use makes in build/goose-http-<ref>/

goose_http_ref=$(sed -n 's/^import http from .*goose-http@\([^"]*\)".*/\1/p' "$root/rest.goose" | head -1)
if [ -z "${GOOSE_HTTP:-}" ]; then
    GOOSE_HTTP=$root/build/goose-http-$goose_http_ref
    if [ ! -d "$GOOSE_HTTP/.git" ]; then
        echo "goose-http.sh: cloning goose-http at $goose_http_ref into $GOOSE_HTTP" >&2
        rm -rf "$GOOSE_HTTP"
        git clone -q https://github.com/kaitk/goose-http.git "$GOOSE_HTTP"
        git -C "$GOOSE_HTTP" -c advice.detachedHead=false checkout -q "$goose_http_ref"
    fi
fi
GOOSE_HTTP=$(cd "$GOOSE_HTTP" && pwd)
export GOOSE_HTTP
