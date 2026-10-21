#!/bin/sh
# Instructions per request for skip60/'s servers, as bench/routes.sh counts
# them: one worker, h2load --h1 -n N -c 256 -m 16 -t 8, and the server's
# instructions retired from /usr/bin/time -l, the kernel's included, divided
# by N. Today's form is built against the package of TODAY, a worktree of
# f7ca662, and skip-based routing against this one. Every case's answer must
# be the same bytes from every form, Date and Server-Timing aside. The rounds
# interleave the servers. macOS only.
#
#   TODAY=../goose-rest-today spikes/12-compact-routes/benchskip.sh
#       (RUNS 3, N 2000000, PORT 29301)
#
# CASES, such as "plain m", runs only those groups' cases. Prints one line
# per run. Design A's servers, built against a worktree of short-routes
# (fc4d51d), are in this script at 99d424a.
set -eu
export LC_ALL=C

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
. "$root/scripts/goose.sh"
today=$(cd "${TODAY:?TODAY names a worktree of today\'s form}" && pwd)
runs=${RUNS:-3}
n=${N:-2000000}
port=${PORT:-29301}
accept='Accept: text/plain,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7'
origin='Origin: https://a.example'
auth='Authorization: Bearer t'
tmp=$(mktemp -d)
tpid=
trap '[ -z "$tpid" ] || pkill -TERM -P "$tpid" 2>/dev/null; rm -rf "$tmp"' EXIT

[ "$(uname -s)" = Darwin ] || { echo "benchskip.sh: macOS only" >&2; exit 2; }

# group, server, source, the root whose package it's built against
servers="plain hand60 hand60 $today
plain short60-skip short60 $root
plain block60 block60 $root
m hand60m hand60m $today
m short60m-skip short60m $root
m block60m block60m $root
c hand60c hand60c $today
c short60c-skip short60c $root
c block60c block60c $root"

# group, case, target, the status class every response must have
cases='plain first /health 2
plain last /v1/reports/exports/42/download 2
plain 404 /v1/reports/exports/42/nope 4
plain 404-outside /v2/nothing 4
plain 405 /v1/reports/exports/42/cancel 4
plain query /v1/projects?page=2&archived=false&q=go 2
m first /health 2
m last /v1/reports/exports/42/download 2
m 404 /v1/reports/exports/42/nope 4
m 405 /v1/reports/exports/42/cancel 4
c last /v1/reports/exports/42/download 2
c failure /v1/reports/time/abc 4
c 404 /v1/reports/exports/42/nope 4
c 405 /v1/reports/exports/42/cancel 4'

selected() { case " ${CASES:-plain m c} " in *" $1 "*) return 0 ;; esac; return 1; }

# The extra fields of a group's requests, one per line.
fields() {
    case $1 in
    m) printf '%s\n%s\n' "$origin" "$auth" ;;
    c) printf '%s\n' "$origin" ;;
    esac
}

start() {
    WORKERS=1 /usr/bin/time -l "$1" http "$port" >/dev/null 2>"$tmp/time" &
    tpid=$!
    until nc -z 127.0.0.1 "$port" 2>/dev/null; do sleep 0.1; done
}

stop() {
    pkill -TERM -P "$tpid"
    wait "$tpid"
    tpid=
}

while read -r group server src base; do
    selected "$group" || continue
    mkdir -p "$base/build/skip60"
    cp "$here/skip60/$src.goose" "$base/build/skip60/$server.goose"
    "$GOOSE" build --standalone -o "$base/build/skip60/$server" "$base/build/skip60/$server.goose" >"$tmp/build" 2>&1 ||
        { cat "$tmp/build" >&2; exit 1; }
done <<EOF
$servers
EOF

# The same bytes from every server of a group.
while read -r group server src base; do
    selected "$group" || continue
    start "$base/build/skip60/$server"
    while read -r g name target class; do
        [ "$g" = "$group" ] || continue
        set -- -s -i
        while IFS= read -r f; do [ -n "$f" ] && set -- "$@" -H "$f"; done <<F
$(fields "$group")
F
        curl "$@" "http://127.0.0.1:$port$target" | grep -v '^Date:\|^Server-Timing:' >"$tmp/$group-$name-$server"
        first=$(ls "$tmp/$group-$name-"* | head -1)
        cmp -s "$first" "$tmp/$group-$name-$server" ||
            { echo "$group $name: $server answers otherwise than ${first##*-}" >&2; diff "$first" "$tmp/$group-$name-$server" >&2; exit 1; }
    done <<EOF
$cases
EOF
    stop
done <<EOF
$servers
EOF

echo "# $(date -u +%FT%TZ), $(sysctl -n machdep.cpu.brand_string)," \
    "macOS $(sw_vers -productVersion), Darwin $(uname -r), $(h2load --version | head -1)," \
    "today $(git -C "$today" rev-parse --short HEAD)," \
    "skip $(git -C "$root" rev-parse --short HEAD), load $(sysctl -n vm.loadavg)"
printf 'group\tcase\tserver\trun\tinstructions/req\tcycles/req\treq/s\n'
for run in $(seq "$runs"); do
    while read -r group name target class; do
        selected "$group" || continue
        while read -r g server src base; do
            [ "$g" = "$group" ] || continue
            start "$base/build/skip60/$server"
            set -- --h1 -n "$n" -c 256 -m 16 -t 8 -H "Connection: keep-alive" -H "$accept"
            while IFS= read -r f; do [ -n "$f" ] && set -- "$@" -H "$f"; done <<F
$(fields "$group")
F
            h2load "$@" "http://127.0.0.1:$port$target" >"$tmp/h2load" 2>&1 || { cat "$tmp/h2load" >&2; exit 1; }
            stop
            got=$(awk -v c="$class" '/^status codes:/ {print $(2 * c - 1)}' "$tmp/h2load")
            if [ "$got" != "$n" ]; then
                echo "$group $name $server: $got of $n responses were ${class}xx" >&2
                cat "$tmp/h2load" >&2
                exit 1
            fi
            rps=$(awk '/^finished in/ {print $4}' "$tmp/h2load")
            awk -v g="$group" -v c="$name" -v s="$server" -v r="$run" -v n="$n" -v rps="$rps" '
                /instructions retired/ { i = $1 } /cycles elapsed/ { y = $1 }
                END { printf "%s\t%s\t%s\t%s\t%.1f\t%.1f\t%.0f\n", g, c, s, r, i / n, y / n, rps }
            ' "$tmp/time"
        done <<EOF
$servers
EOF
    done <<EOF
$cases
EOF
done
echo "# load after: $(sysctl -n vm.loadavg)"
