#!/bin/sh
# Builds each example under examples/, or each directory given as an
# argument, such as docs/tutorial/*/, serves it on a local port, sends the
# requests its requests.sh lists, one per route at least, and compares each
# answer's status and body with the expected.txt beside it. A request is a
# line `req METHOD PATH [curl options]`; its answer is the line
# `METHOD PATH STATUS BODY`, without BODY for an empty one. An example's
# setup.sh, where it has one, is sourced before the example starts, to set
# its environment.
#
# GOOSE names the compiler (default: the pinned release, scripts/goose.sh).
# BIN is where the examples are built and their output goes (default:
# build/examples), and PREBUILT=1 runs the ones already there without a
# compiler, as scripts/test-aarch64.sh does on a machine that has none.
# RSS=1 prints each example's peak RSS on Linux, once it answers and after its
# requests. The examples listen on 127.0.0.1, from port 18081 up.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
[ -n "${PREBUILT:-}" ] || . "$root/scripts/goose.sh"
goose=${GOOSE:-}
out=${BIN:-$root/build/examples}
mkdir -p "$out"

peak() { sed -n 's/^VmHWM:[[:space:]]*//p' "/proc/$pid/status"; }

[ "$#" -gt 0 ] || set -- "$root"/examples/*/

port=18081
for dir in "$@"; do
    dir=${dir%/}
    name=$(basename "$dir")
    echo
    echo "== example $name"
    [ -n "${PREBUILT:-}" ] || "$goose" build -o "$out/$name" "$dir/main.goose"
    [ ! -f "$dir/setup.sh" ] || . "$dir/setup.sh"
    "$out/$name" "$port" 2>"$out/$name.log" &
    pid=$!
    tries=0
    until curl -s -o /dev/null "http://127.0.0.1:$port/health"; do
        tries=$((tries + 1))
        if [ "$tries" -gt 100 ]; then
            echo "example $name: no answer on port $port"
            kill "$pid" 2>/dev/null || true
            exit 1
        fi
        sleep 0.1
    done
    rss=
    [ -z "${RSS:-}" ] || [ ! -r "/proc/$pid/status" ] || rss=$(peak)
    req() {
        method=$1
        path=$2
        shift 2
        # A request that gives up, such as with -m, prints 000 and goes on,
        # with no body: curl then leaves the file as it was.
        : >"$out/body"
        code=$(curl -s -o "$out/body" -w '%{http_code}' -X "$method" "$@" "http://127.0.0.1:$port$path") || true
        body=$(cat "$out/body")
        if [ -n "$body" ]; then echo "$method $path $code $body"; else echo "$method $path $code"; fi
    }
    status=0
    . "$dir/requests.sh" >"$out/$name.out" || status=$?
    [ -z "$rss" ] || echo "$name: peak RSS $rss at start, $(peak) after the requests"
    kill "$pid"
    wait "$pid" 2>/dev/null || true
    [ "$status" -eq 0 ] || { echo "example $name: a request failed"; exit 1; }
    diff -u "$dir/expected.txt" "$out/$name.out"
    port=$((port + 1))
done
