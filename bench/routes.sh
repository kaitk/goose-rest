#!/bin/sh
# Instructions per request for the if chain at 60 routes
# (bench/routes/routes60.goose) against one route, on the first route, the
# last, a 404 in the last scope and one outside every scope, and a 405 in the
# last scope. Each case's one-route server answers the same request with the
# same bytes: routes1.goose has routes60's first route, routes1_last.goose
# its last, and routes1_post.goose the POST route the 405 is a GET of.
#
# gen60.goose serves the same routes through the router goose-rest
# gen writes from test/gen/routes.json. It answers a 404 and a 405 in the
# JSON error shape, a body of 21 to 30 bytes, where the others send none.
#
# hand60.goose serves the same routes written by hand on goose-rest,
# through rest::serve_epoll, and answers as gen60 does. The query case reads
# GET /v1/projects's three query parameters, which routes60 ignores. genr60.goose
# is gen60 behind rest::routes and one hand-written route, as a program serves
# a route its schema can't describe.
#
# goose-http's bench/count.sh's load on macOS, which has no perf: one worker,
# h2load --h1 -n N -c 256 -m 16 -t 8 with count.sh's headers, and the server's
# instructions retired and cycles elapsed from /usr/bin/time -l, the kernel's
# included, divided by N (goose-http's docs/development.md, "macOS"). Every
# request is a GET: h2load's POSTs ran at a tenth of its GETs' rate, which
# buried the router's cost under the kernel's. h2load counts a 4xx as failed,
# so each run checks the status class instead.
# The rounds interleave the servers.
#
#   bench/routes.sh   (RUNS 3, N 2000000, PORT 29281, SERVERS all)
#
# GOOSE names the compiler (default: the pinned release, scripts/goose.sh).
# SERVERS, such as "gen60 hand60", runs only those servers' cases. Prints one
# line per run.
set -eu
export LC_ALL=C

root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/scripts/goose.sh"
goose=$GOOSE
bin=$root/build/routes
runs=${RUNS:-3}
n=${N:-2000000}
port=${PORT:-29281}
accept='Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7'
tmp=$(mktemp -d)
tpid=
trap '[ -z "$tpid" ] || pkill -TERM -P "$tpid" 2>/dev/null; rm -rf "$tmp"' EXIT

[ "$(uname -s)" = Darwin ] || { echo "bench/routes.sh: macOS only" >&2; exit 2; }

mkdir -p "$bin"
for s in routes60 routes1 routes1_last routes1_post hand60; do
    "$goose" build --standalone -o "$bin/$s" "$root/bench/routes/$s.goose" >"$tmp/build" 2>&1 ||
        { cat "$tmp/build" >&2; exit 1; }
done
# gen60 and genr60 import the generated router beside them, so they're built
# from copies next to one.
mkdir -p "$bin/gen"
cp "$root/bench/routes/gen60.goose" "$root/bench/routes/genr60.goose" "$root/bench/routes/app.goose" "$bin/gen/"
{ "$goose" "$root/gen/main.goose" -- gen "$root/test/gen/routes.json" -o "$bin/gen/routes_gen.goose" &&
    "$goose" build --standalone -o "$bin/gen60" "$bin/gen/gen60.goose" &&
    "$goose" build --standalone -o "$bin/genr60" "$bin/gen/genr60.goose"; } >"$tmp/build" 2>&1 ||
    { cat "$tmp/build" >&2; exit 1; }

# case, server, target, the status class every response must have
cases='first routes60 /health 2
first gen60 /health 2
first genr60 /health 2
first hand60 /health 2
first routes1 /health 2
last routes60 /v1/reports/exports/42/download 2
last gen60 /v1/reports/exports/42/download 2
last genr60 /v1/reports/exports/42/download 2
last hand60 /v1/reports/exports/42/download 2
last routes1_last /v1/reports/exports/42/download 2
404 routes60 /v1/reports/exports/42/nope 4
404 gen60 /v1/reports/exports/42/nope 4
404 genr60 /v1/reports/exports/42/nope 4
404 hand60 /v1/reports/exports/42/nope 4
404 routes1_last /v1/reports/exports/42/nope 4
404-outside routes60 /v2/nothing 4
404-outside gen60 /v2/nothing 4
404-outside genr60 /v2/nothing 4
404-outside hand60 /v2/nothing 4
404-outside routes1 /v2/nothing 4
405 routes60 /v1/reports/exports/42/cancel 4
405 gen60 /v1/reports/exports/42/cancel 4
405 genr60 /v1/reports/exports/42/cancel 4
405 hand60 /v1/reports/exports/42/cancel 4
405 routes1_post /v1/reports/exports/42/cancel 4
query routes60 /v1/projects?page=2&archived=false&q=go 2
query gen60 /v1/projects?page=2&archived=false&q=go 2
query genr60 /v1/projects?page=2&archived=false&q=go 2
query hand60 /v1/projects?page=2&archived=false&q=go 2'

echo "# $(date -u +%FT%TZ), $(sysctl -n machdep.cpu.brand_string)," \
    "macOS $(sw_vers -productVersion), Darwin $(uname -r), $(h2load --version | head -1)," \
    "goose-rest $(git -C "$root" rev-parse --short HEAD), load $(sysctl -n vm.loadavg)"
printf 'case\tserver\trun\tinstructions/req\tcycles/req\treq/s\n'
for run in $(seq "$runs"); do
    while read -r name server target class; do
        case " ${SERVERS:-$server} " in *" $server "*) ;; *) continue ;; esac
        WORKERS=1 /usr/bin/time -l "$bin/$server" http "$port" >/dev/null 2>"$tmp/time" &
        tpid=$!
        until nc -z 127.0.0.1 "$port" 2>/dev/null; do sleep 0.1; done
        h2load --h1 -n "$n" -c 256 -m 16 -t 8 -H "Connection: keep-alive" \
            -H "$accept" "http://127.0.0.1:$port$target" >"$tmp/h2load" 2>&1 ||
            { cat "$tmp/h2load" >&2; exit 1; }
        pkill -TERM -P "$tpid"
        wait "$tpid"
        tpid=
        got=$(awk -v c="$class" '/^status codes:/ {print $(2 * c - 1)}' "$tmp/h2load")
        if [ "$got" != "$n" ]; then
            echo "$name $server: $got of $n responses were ${class}xx" >&2
            exit 1
        fi
        rps=$(awk '/^finished in/ {print $4}' "$tmp/h2load")
        awk -v c="$name" -v s="$server" -v r="$run" -v n="$n" -v rps="$rps" '
            /instructions retired/ { i = $1 } /cycles elapsed/ { y = $1 }
            END { printf "%s\t%s\t%s\t%.1f\t%.1f\t%.0f\n", c, s, r, i / n, y / n, rps }
        ' "$tmp/time"
    done <<EOF
$cases
EOF
done
echo "# load after: $(sysctl -n vm.loadavg)"
