#!/bin/sh
# Runs each test/test_*.goose through TinyCC. Each one asserts what it tests,
# so the first failure stops the run.
#
# GOOSE names the compiler (default: goose on PATH).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
goose=${GOOSE:-goose}
for t in "$root"/test/test_*.goose; do
    "$goose" "$t"
done
