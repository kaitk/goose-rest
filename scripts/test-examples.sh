#!/bin/sh
# Builds each example under examples/, serves it on a local port, sends the
# requests its requests.sh lists, one per route at least, and compares each
# answer's status and body with the expected.txt beside it. A request is a
# line `req METHOD PATH [curl options]`; its answer is the line
# `METHOD PATH STATUS BODY`, without BODY for an empty one. An example's
# setup.sh, where it has one, is sourced before the example starts, to set
# its environment.
#
# GOOSE names the compiler (default: goose on PATH). The examples listen on
# 127.0.0.1, from port 18081 up.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
goose=${GOOSE:-goose}
out="$root/build/examples"
mkdir -p "$out"

port=18081
for dir in "$root"/examples/*/; do
    name=$(basename "$dir")
    echo
    echo "== example $name"
    "$goose" build -o "$out/$name" "$dir/main.goose"
    [ ! -f "$dir/setup.sh" ] || . "$dir/setup.sh"
    "$out/$name" "$port" 2>"$out/$name.log" &
    pid=$!
    tries=0
    until curl -s -o /dev/null "http://127.0.0.1:$port/health"; do
        tries=$((tries + 1))
        if [ "$tries" -gt 50 ]; then
            echo "example $name: no answer on port $port"
            kill "$pid" 2>/dev/null || true
            exit 1
        fi
        sleep 0.1
    done
    req() {
        method=$1
        path=$2
        shift 2
        code=$(curl -s -o "$out/body" -w '%{http_code}' -X "$method" "$@" "http://127.0.0.1:$port$path")
        body=$(cat "$out/body")
        if [ -n "$body" ]; then echo "$method $path $code $body"; else echo "$method $path $code"; fi
    }
    status=0
    . "$dir/requests.sh" >"$out/$name.out" || status=$?
    kill "$pid"
    wait "$pid" 2>/dev/null || true
    [ "$status" -eq 0 ] || { echo "example $name: a request failed"; exit 1; }
    diff -u "$dir/expected.txt" "$out/$name.out"
    port=$((port + 1))
done
