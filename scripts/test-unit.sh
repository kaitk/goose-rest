#!/bin/sh
# Runs each test/test_*.goose through TinyCC. Each one asserts what it tests,
# so the first failure stops the run.
#
# GOOSE names the compiler (default: the pinned release, scripts/goose.sh).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/scripts/goose.sh"
goose=$GOOSE
for t in "$root"/test/test_*.goose; do
    "$goose" "$t"
done
