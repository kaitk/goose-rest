#!/bin/sh
# Instructions per request for a genroutes.sh program in each of FORMS, by
# default today's form (hand) and design A (short), as bench/routes.sh counts
# them: one worker, h2load --h1 -n N -c 256 -m 16 -t 8, and the server's
# instructions retired from /usr/bin/time -l, the kernel's included, divided
# by N. The rounds interleave the servers. macOS only.
#
#   spikes/12-compact-routes/benchroutes.sh
#       (AREAS 3, MODULES 37, ROLES 0, CORS 0, MIDDLE /patient/visit, LAST /staff/audit,
#        FORMS "hand short", RUNS 3, N 2000000, PORT 29291)
#
# AREAS, MODULES, ROLES, and CORS go to genroutes.sh; with CORS 1 every
# request has an Origin the middleware allows. MIDDLE and LAST are the
# scopes of the middle and last cases, a GET route in each: the last area's
# last scope for LAST. TODAY, a worktree of today's package, builds hand
# against it rather than this one's, whose plod::routes is design A's. GOOSE
# names the compiler (default: the pinned one, scripts/goose.sh). Prints each
# build's time, then one line per run.
set -eu
export LC_ALL=C

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
. "$root/scripts/goose.sh"
areas=${AREAS:-3}
modules=${MODULES:-37}
roles=${ROLES:-0}
cors=${CORS:-0}
middle=${MIDDLE:-/patient/visit}
last=${LAST:-/staff/audit}
forms=${FORMS:-hand short}
today=$(cd "${TODAY:-$root}" && pwd)
prog=routes-$areas-$modules-$roles-$cors
runs=${RUNS:-3}
n=${N:-2000000}
port=${PORT:-29291}
accept='Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7'
tmp=$(mktemp -d)
tpid=
trap '[ -z "$tpid" ] || pkill -TERM -P "$tpid" 2>/dev/null; rm -rf "$tmp"' EXIT

[ "$(uname -s)" = Darwin ] || { echo "benchroutes.sh: macOS only" >&2; exit 2; }

# Where form f is built: the programs import the package as ../../, so
# they're written two levels below the root.
bin_of() { if [ "$1" = hand ]; then echo "$today/build/$prog"; else echo "$root/build/$prog"; fi; }

for f in $forms; do
    bin=$(bin_of "$f")
    mkdir -p "$bin"
    AREAS=$areas MODULES=$modules ROLES=$roles CORS=$cors sh "$here/genroutes.sh" "$f" >"$bin/$f.goose"
    start=$(date +%s)
    "$GOOSE" build --standalone -o "$bin/$f" "$bin/$f.goose" >"$tmp/build" 2>&1 ||
        { cat "$tmp/build" >&2; exit 1; }
    echo "# built $f in $(($(date +%s) - start)) s, $(wc -c <"$bin/$f" | tr -d ' ') bytes"
done

# case, target, the status class every response must have
cases="first /health 2
middle $middle/42/history 2
last $last/42/history 2
404 $last/42/nope 4
404-outside /nothing 4
405 $last/42/confirm 4"

# Every case's answer the same bytes from every form, and a failure in the
# middle area's check.
for server in $forms; do
    WORKERS=1 "$(bin_of "$server")/$server" http "$port" >/dev/null 2>&1 &
    tpid=$!
    until nc -z 127.0.0.1 "$port" 2>/dev/null; do sleep 0.1; done
    while read -r name target class; do
        curl -s -i -H "Origin: https://a.example" -H "X-Tenant: other" "http://127.0.0.1:$port$target" |
            grep -v '^Date:' >"$tmp/$name-tenant@$server"
        curl -s -i -H "Origin: https://a.example" "http://127.0.0.1:$port$target" | grep -v '^Date:' >"$tmp/$name@$server"
        for c in "$name" "$name-tenant"; do
            first=$(ls "$tmp/$c@"* | head -1)
            cmp -s "$first" "$tmp/$c@$server" ||
                { echo "$c: $server answers otherwise than ${first##*@}" >&2; diff "$first" "$tmp/$c@$server" >&2; exit 1; }
        done
    done <<EOF
$cases
EOF
    kill "$tpid"
    wait "$tpid" 2>/dev/null || true
    tpid=
done

echo "# $(date -u +%FT%TZ), $(sysctl -n machdep.cpu.brand_string)," \
    "macOS $(sw_vers -productVersion), Darwin $(uname -r), $(h2load --version | head -1)," \
    "Plod $(git -C "$root" rev-parse --short HEAD), today $(git -C "$today" rev-parse --short HEAD)," \
    "AREAS $areas MODULES $modules ROLES $roles CORS $cors, load $(sysctl -n vm.loadavg)"
printf 'case\tserver\trun\tinstructions/req\tcycles/req\treq/s\n'
for run in $(seq "$runs"); do
    while read -r name target class; do
        for server in $forms; do
            WORKERS=1 /usr/bin/time -l "$(bin_of "$server")/$server" http "$port" >/dev/null 2>"$tmp/time" &
            tpid=$!
            until nc -z 127.0.0.1 "$port" 2>/dev/null; do sleep 0.1; done
            set -- --h1 -n "$n" -c 256 -m 16 -t 8 -H "Connection: keep-alive" -H "$accept"
            [ "$cors" != 1 ] || set -- "$@" -H "Origin: https://a.example"
            h2load "$@" "http://127.0.0.1:$port$target" >"$tmp/h2load" 2>&1 ||
                { cat "$tmp/h2load" >&2; exit 1; }
            pkill -TERM -P "$tpid"
            wait "$tpid"
            tpid=
            got=$(awk -v c="$class" '/^status codes:/ {print $(2 * c - 1)}' "$tmp/h2load")
            if [ "$got" != "$n" ]; then
                echo "$name $server: $got of $n responses were ${class}xx" >&2
                cat "$tmp/h2load" >&2
                exit 1
            fi
            rps=$(awk '/^finished in/ {print $4}' "$tmp/h2load")
            awk -v c="$name" -v s="$server" -v r="$run" -v n="$n" -v rps="$rps" '
                /instructions retired/ { i = $1 } /cycles elapsed/ { y = $1 }
                END { printf "%s\t%s\t%s\t%.1f\t%.1f\t%.0f\n", c, s, r, i / n, y / n, rps }
            ' "$tmp/time"
        done
    done <<EOF
$cases
EOF
done
echo "# load after: $(sysctl -n vm.loadavg)"
