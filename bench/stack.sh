#!/bin/sh
# Instructions per request for a JSON body and for the middleware stack, on
# macOS, beside bench/routes.sh's routers. The server is the REST benchmark's
# (bench/rest/plod/main.goose); the requests are bench/stack/pipelined.lua's:
#
#   json   tier F, POST /json read with plod::take
#   item   GET /api/items/42 on tier A, then on tier M, which is tier A inside
#          plod::timed, plod::cors, and plod::bearer: the difference is the stack
#   post   POST /api/items/7 with a JSON body, on tiers A and M the same way
#   error  GET /api/items/0 on tier A, answered with 404 item_not_found
#
# One worker on http::serve_epoll over kqueue, wrk -t 8 -c 256 -d D, each
# connection pipelined 16 deep, as bench/routes.sh's h2load -m 16 is: unpipelined,
# the kernel's share is ten times the server's. The server's instructions
# retired from /usr/bin/time -l, the kernel's included, less those of the same
# server started and stopped without load (loading tier A's datasets), divided
# by wrk's request count. The rounds interleave the cells.
#
#   bench/stack.sh   (RUNS 3, D 10, PORT 29282)
#
# GOOSE names the compiler (default: the pinned release, scripts/goose.sh).
# REST_DATA names the datasets goose-http's bench/rest.sh build writes
# (default: build/rest in the goose-http checkout scripts/goose-http.sh finds).
# Prints one line per run.
set -eu
export LC_ALL=C

root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/scripts/goose.sh"
goose=$GOOSE
bin=$root/build/stack
runs=${RUNS:-3}
d=${D:-10}
port=${PORT:-29282}
if [ -z "${REST_DATA:-}" ]; then
    . "$root/scripts/goose-http.sh"
    REST_DATA=$GOOSE_HTTP/build/rest
fi
data=$REST_DATA
tmp=$(mktemp -d)
tpid=
trap '[ -z "$tpid" ] || pkill -INT -P "$tpid" 2>/dev/null; rm -rf "$tmp"' EXIT

[ "$(uname -s)" = Darwin ] || { echo "bench/stack.sh: macOS only" >&2; exit 2; }
[ -f "$data/arena-items.json" ] || { echo "bench/stack.sh: no datasets in $data" >&2; exit 2; }

mkdir -p "$bin"
"$goose" build --standalone -o "$bin/rest" "$root/bench/rest/plod/main.goose" >"$tmp/build" 2>&1 ||
    { cat "$tmp/build" >&2; exit 1; }

start() {
    REST_DATA="$data" TIER=$1 WORKERS=1 LOOP=epoll /usr/bin/time -l "$bin/rest" "$port" >/dev/null 2>"$tmp/time" &
    tpid=$!
    until nc -z 127.0.0.1 "$port" 2>/dev/null; do sleep 0.05; done
}

# Stops the server and sets retired to its instructions retired. Not run in
# a subshell, so that tpid is cleared for the trap.
stop() {
    pkill -INT -P "$tpid"
    wait "$tpid" || true
    tpid=
    retired=$(awk '/instructions retired/ { print $1 }' "$tmp/time")
}

# case, tier
cells='json f
item a
item m
post a
post m
error a'

echo "# $(date -u +%FT%TZ), $(sysctl -n machdep.cpu.brand_string)," \
    "macOS $(sw_vers -productVersion), Darwin $(uname -r), $(wrk -v 2>&1 | head -1 | cut -d' ' -f1-2)," \
    "Plod $(git -C "$root" rev-parse --short HEAD), load $(sysctl -n vm.loadavg)"
printf 'case\ttier\trun\tinstructions/req\treq/s\n'
for run in $(seq "$runs"); do
    while read -r name tier; do
        start "$tier"
        stop
        idle=$retired
        start "$tier"
        wrk -t 8 -c 256 -d "$d" -s "$root/bench/stack/pipelined.lua" "http://127.0.0.1:$port" -- "$name" \
            >"$tmp/wrk" 2>&1 || { cat "$tmp/wrk" >&2; exit 1; }
        stop
        busy=$retired
        if ! awk -v c="$name" '
            /requests in/ { n = $1 }
            /Non-2xx or 3xx responses/ { errors = $NF }
            /Socket errors/ { sockets = 1 }
            END { exit sockets || n == 0 || errors != (c == "error" ? n : 0) }
        ' "$tmp/wrk"; then
            echo "$name $tier: unexpected response or socket errors" >&2
            cat "$tmp/wrk" >&2
            exit 1
        fi
        awk -v c="$name" -v t="$tier" -v r="$run" -v busy="$busy" -v idle="$idle" '
            /requests in/ { n = $1 } /Requests\/sec/ { rps = $2 }
            END { printf "%s\t%s\t%s\t%.1f\t%.0f\n", c, t, r, (busy - idle) / n, rps }
        ' "$tmp/wrk"
    done <<EOF
$cells
EOF
done
echo "# load after: $(sysctl -n vm.loadavg)"
