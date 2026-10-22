#!/bin/sh
# The REST benchmark (docs/benchmarks.md): goose-http's REST tiers A to D
# through its own bench/rest.sh, with Plod, Axum, actix-web, ntex,
# dusty with a route per path, and Aegon beside goose-http alone, and Plod's tiers
# F, R, and M (bench/rest/tiers) run here the same way. Results go to
# bench/results/<date>-rest-<machine>/ unless OUT names another directory.
#
#   bench/rest.sh build   goose-http's bench/rest.sh build, then this
#                         repository's servers into goose-http's build/rest:
#                         rest-goose-rest, rest-axum, rest-actix-web,
#                         rest-ntex, rest-dusty-routes, and, on Linux,
#                         rest-aegon and rest-aegon-small; with ONLY=goose,
#                         goose-http's ONLY=goose build and rest-goose-rest
#                         alone
#   bench/rest.sh check   each server on each tier it serves, against
#                         goose-http's bench/rest/check.py and
#                         bench/rest/tiers/check.py, unpinned: runs on macOS
#   bench/rest.sh run     goose-http's bench/rest.sh run with SERVERS, then
#                         tiers F, R, and M at saturation, into the same OUT
#   bench/rest.sh count   as root: count.sh's user instructions per request on
#                         goose-http alone and Plod, one request each,
#                         on LOOP's loop (default: epoll; or uring)
#
# Linux only but for check: run and count need taskset, /proc, and perf.
#
# The servers, by name: goose-epoll and goose-uring, goose-http alone
# (goose-http's build/rest/rest; on tier F, goose-*-bare, this repository's
# server with BARE=1 on http::serve); goose-epoll-rest and goose-uring-rest,
# Plod; goose-*-rest-gen, Plod through the generated router, tier
# R only; axum, actix-web, ntex, dusty-routes; aegon, and aegon-small with
# its buffers for a low memlock limit; and goose-http's dusty, its
# catch-all entry, and hyper, as anchors to its tables.
#
# What run measures beyond goose-http's bench/rest.sh, each server with
# WORKERS workers on SERVER_CPUS and wrk on CLIENT_CPUS, a fresh server per
# cell, WARMUP s discarded and then DURATION s, with the server's CPU time and
# peak RSS, RUNS rounds interleaved:
#
#   F  each of tier-f.lua's three routes, CLIENT_THREADS threads, 256
#      connections
#   R  tier-r.lua, every GitHub route, the same
#   M  tier-m.lua beside tier-a.lua, both JSON ways' serialize, the same
#
# Settings, from the environment, beside goose-http's bench/rest.sh's own
# (SERVER_CPUS, CLIENT_CPUS, CLIENT_THREADS, RUNS, DURATION, WARMUP, PORT,
# MACHINE, DATA, OUT):
#   GOOSE        the compiler, for both repositories' builds (default: the
#                pinned release, scripts/goose.sh)
#   GOOSE_HTTP   a goose-http checkout at the pin plod.goose names (default:
#                a clone at the pin in build/, scripts/goose-http.sh)
#   SERVERS      tiers A to D: goose-uring goose-epoll goose-uring-rest
#                goose-epoll-rest axum actix-web ntex dusty-routes aegon
#                aegon-small dusty hyper
#   EXTRA        tiers F, R, and M: goose-uring-rest goose-epoll-rest axum
#                actix-web ntex dusty-routes aegon aegon-small, with
#                goose-*-bare on F and goose-*-rest-gen on R added
#   AEGON_CXX    the C++ compiler for Aegon (default: g++-16)
#   TIERS        f r m, or a subset; STEPS goose-http's, or "none" to skip it
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/scripts/goose-http.sh"
gh=$GOOSE_HTTP
cache=${CACHE:-$HOME/.cache/goose-http-bench}
. "$root/scripts/goose.sh"
bin=$gh/build/rest
data=${DATA:-$gh/build/rest}
tiers=$root/bench/rest/tiers
PATH=$HOME/.cargo/bin:$PATH
export GOOSE_HTTP=$gh

# goose-http at the pin plod.goose imports.
ref=$(sed -n 's/^import http from .*goose-http@\([^"]*\)".*/\1/p' "$root/plod.goose" | head -1)
pin=$(git -C "$gh" rev-parse --verify -q "$ref^{commit}" || true)
[ -n "$pin" ] && [ "$(git -C "$gh" rev-parse HEAD)" = "$pin" ] ||
    echo "bench/rest.sh: $gh isn't at goose-http's pin $ref" >&2

case ${1:-} in
build)
    # OWN=1 builds only this repository's servers, as on macOS, where
    # goose-http's build can't run; the datasets must be in DATA already.
    [ "${OWN:-}" = 1 ] || "$gh/bench/rest.sh" build
    goose=$GOOSE
    "$goose" "$root/gen/main.goose" -- gen "$root/bench/rest/goose-rest/github.json" -o "$bin/github_gen.goose" >/dev/null
    cmp -s "$bin/github_gen.goose" "$root/bench/rest/goose-rest/github_gen.goose" ||
        { echo "bench/rest.sh: github_gen.goose is stale; regenerate it (scripts/test.sh)"; exit 1; }
    if [ "$(uname -s)" = Darwin ]; then
        echo "bench/rest.sh: rest-goose-rest calls glibc's mallopt; build it on Linux" >&2
    else
        "$goose" build --cc gcc --standalone -o "$bin/rest-goose-rest" "$root/bench/rest/goose-rest/main.goose"
    fi
    if [ "${ONLY:-}" = goose ]; then
        ls -l "$bin"
        exit 0
    fi
    for name in axum actix-web ntex; do
        (cd "$cache" && RUSTFLAGS="-C target-cpu=native" cargo build --release --locked \
            --manifest-path "$root/bench/rest/$name/Cargo.toml" --target-dir "$cache/target-rest-$name")
        cp "$cache/target-rest-$name/release/rest-$name" "$bin/rest-$name"
    done
    # As goose-http's bench/rest.sh builds its dusty: from a copy in CACHE, for
    # HttpArena's target and CPU.
    zig=${ZIG:-zig}
    case $(uname -s)-$(uname -m) in
    Darwin-*) target=native cpu=native ;;
    *-aarch64)
        target=aarch64-linux-musl cpu=native
        grep -q '^CPU implementer.*0x61' /proc/cpuinfo && cpu=apple_m1
        ;;
    *) target=x86_64-linux-musl cpu=x86_64_v3+aes+pclmul+adx ;;
    esac
    rm -rf "$cache/app-rest-dusty-routes"
    mkdir -p "$cache/app-rest-dusty-routes"
    cp -r "$root/bench/rest/dusty/." "$cache/app-rest-dusty-routes/"
    (cd "$cache/app-rest-dusty-routes" && "$zig" build --cache-dir "$cache/zig-cache" \
        --global-cache-dir "$cache/zig-global" --prefix "$cache/rest-dusty-routes-out" \
        -Dtarget=$target -Dcpu=$cpu -Dgithub="$tiers/github.txt" --release=fast)
    cp "$cache/rest-dusty-routes-out/bin/rest-dusty" "$bin/rest-dusty-routes"
    # Aegon, which fetches itself and glaze (bench/rest/aegon/NOTES.md), with
    # ngtcp2 built at the release its HTTP/3 code needs into CACHE.
    if [ "$(uname -s)" = Linux ]; then
        ngtcp2=v1.25.0
        prefix=$cache/aegon-prefix
        if [ "$(cat "$prefix/ngtcp2.txt" 2>/dev/null)" != $ngtcp2 ]; then
            rm -rf "$cache/ngtcp2-src" "$cache/ngtcp2-build" "$prefix"
            git clone -q --depth 1 --branch $ngtcp2 https://github.com/ngtcp2/ngtcp2.git "$cache/ngtcp2-src"
            cmake -S "$cache/ngtcp2-src" -B "$cache/ngtcp2-build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_INSTALL_PREFIX="$prefix" -DENABLE_OPENSSL=ON -DENABLE_LIB_ONLY=ON -DBUILD_TESTING=OFF \
                -DENABLE_SHARED_LIB=OFF -DENABLE_STATIC_LIB=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
            cmake --build "$cache/ngtcp2-build"
            cmake --install "$cache/ngtcp2-build"
            echo $ngtcp2 >"$prefix/ngtcp2.txt"
        fi
        CXX=${AEGON_CXX:-g++-16} cmake -S "$root/bench/rest/aegon" -B "$cache/aegon-build" -G Ninja \
            -DFETCHCONTENT_BASE_DIR="$cache/aegon-deps" -DCMAKE_PREFIX_PATH="$prefix"
        cmake --build "$cache/aegon-build"
        cp "$cache/aegon-build/rest-aegon" "$cache/aegon-build/rest-aegon-small" "$bin/"
    else
        echo "bench/rest.sh: Aegon builds on Linux only" >&2
    fi
    ls -l "$bin"
    exit 0
    ;;
check | run | count) ;;
*)
    echo "usage: bench/rest.sh build | check | run | count"
    exit 2
    ;;
esac

# Aegon registers its buffers with io_uring, which locks them, and HttpArena
# runs it with memlock unlimited; the other servers lock nothing.
ulimit -l unlimited 2>/dev/null || echo "bench/rest.sh: memlock stays at $(ulimit -l) KB; Aegon may not register its buffers" >&2

servers=${SERVERS:-goose-uring goose-epoll goose-uring-rest goose-epoll-rest axum actix-web ntex dusty-routes aegon aegon-small dusty hyper}
extra=${EXTRA:-goose-uring-rest goose-epoll-rest axum actix-web ntex dusty-routes aegon aegon-small}
which=${TIERS:-f r m}
port=${PORT:-29380}
url=http://127.0.0.1:$port

# The servers of tier $1 among EXTRA, with goose-http alone on F and the
# generated router on R.
extra_of() {
    for s in $extra; do
        case $1:$s in
        f:goose-uring-rest | f:goose-epoll-rest) echo "${s%-rest}-bare" ;;
        esac
        echo "$s"
        case $1:$s in
        r:goose-uring-rest | r:goose-epoll-rest) echo "$s-gen" ;;
        esac
    done
}

# The binary, and the environment, that serve server $1.
binary() {
    case $1 in
    goose-uring | goose-epoll) echo rest ;;
    goose-*-bare | goose-*-rest | goose-*-rest-gen) echo rest-goose-rest ;;
    *) echo "rest-$1" ;;
    esac
}
env_of() {
    case $1 in goose-uring*) printf 'LOOP=uring ' ;; goose-epoll*) printf 'LOOP=epoll ' ;; esac
    case $1 in *-bare) printf 'BARE=1 ' ;; *-rest-gen) printf 'ROUTER=gen ' ;; esac
    printf 'ROUTES=%s\n' "$tiers/github.txt"
}

# Starts server $1 on tier $2 with JSON way $3, with taskset when $4 is
# pinned, and waits until it listens.
pid=
trap '[ -z "$pid" ] || kill "$pid" 2>/dev/null' EXIT
start() {
    if nc -z 127.0.0.1 "$port" 2>/dev/null; then
        echo "bench/rest.sh: port $port is taken; set PORT"
        exit 1
    fi
    if [ "$4" = pinned ]; then
        env $(env_of "$1") REST_DATA="$data" TIER="$2" JSON="$3" WORKERS="$workers" \
            taskset -c "$server_cpus" "$bin/$(binary "$1")" "$port" >>"$log/$1.log" 2>&1 &
    else
        env $(env_of "$1") REST_DATA="$data" TIER="$2" JSON="$3" WORKERS="${WORKERS:-4}" \
            "$bin/$(binary "$1")" "$port" >>"$log/$1.log" 2>&1 &
    fi
    pid=$!
    tries=0
    until nc -z 127.0.0.1 "$port" 2>/dev/null; do
        tries=$((tries + 1))
        kill -0 "$pid" 2>/dev/null && [ $tries -lt 600 ] || { tail -3 "$log/$1.log"; exit 1; }
        sleep 0.1
    done
}

# Stops the server and waits until its port can be bound again.
halt() {
    kill $pid
    wait $pid 2>/dev/null || true
    pid=
    tries=0
    until python3 -c 'import socket, sys
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", int(sys.argv[1])))' "$port" 2>/dev/null; do
        tries=$((tries + 1))
        [ $tries -lt 100 ] || { echo "bench/rest.sh: port $port stays taken"; exit 1; }
        sleep 0.1
    done
}

if [ "$1" = check ]; then
    log=${OUT:-$root/build/rest-check}
    mkdir -p "$log"
    for s in $servers; do
        case $s in goose-uring | goose-epoll | dusty | hyper) continue ;; esac
        [ -x "$bin/$(binary "$s")" ] || { echo "check: no $bin/$(binary "$s"); skipped"; continue; }
        for t in a b c d; do
            # Aegon has no tier D; no_d in goose-http's bench/rest.sh says why.
            case $t:$s in d:aegon | d:aegon-small)
                echo "$s d: skipped, as goose-http's bench/rest.sh skips it"
                continue
                ;;
            esac
            for j in serialize template; do
                [ "$t" = d ] && [ "$j" = template ] && continue
                start "$s" "$t" "$j" free
                printf '%s %s %s: ' "$s" "$t" "$j"
                python3 "$gh/bench/rest/check.py" "$port" "$data" "$t" 2>&1 | tail -1
                halt
            done
        done
    done
    for t in $which; do
        for s in $(extra_of "$t"); do
            [ -x "$bin/$(binary "$s")" ] || continue
            start "$s" "$t" serialize free
            printf '%s %s: ' "$s" "$t"
            python3 "$tiers/check.py" "$port" "$t" "$data" 2>&1 | tail -1
            halt
        done
    done
    exit 0
fi

server_cpus=${SERVER_CPUS:-0-3}
client_cpus=${CLIENT_CPUS:-4-15}
threads=${CLIENT_THREADS:-8}
workers=${WORKERS:-$(taskset -c "$server_cpus" nproc)}
runs=${RUNS:-3}
duration=${DURATION:-15}
warmup=${WARMUP:-5}
machine=${MACHINE:-$(hostname -s)}
hz=$(getconf CLK_TCK)

if [ "$1" = count ]; then
    # count.sh starts build/bench/NAME with "PORT" when NAME doesn't start with
    # goose, and passes on the environment.
    ln -sf "$bin/rest" "$gh/build/bench/restc-http"
    ln -sf "$bin/rest-goose-rest" "$gh/build/bench/restc-rest"
    export REST_DATA="$data" LOOP="${LOOP:-epoll}"
    # tier, target, status class, servers
    while read -r tier target class servers; do
        echo "== TIER=$tier $target"
        for s in $servers; do
            case $s in
            bare) TIER=$tier BARE=1 TARGET=$target STATUS=$class "$gh/bench/count.sh" restc-rest ;;
            gen) TIER=$tier ROUTER=gen TARGET=$target STATUS=$class "$gh/bench/count.sh" restc-rest ;;
            *) TIER=$tier TARGET=$target STATUS=$class "$gh/bench/count.sh" "restc-$s" ;;
            esac
        done
    done <<EOF
a /api/items/1 2 http rest
a /api/me 4 http rest
a /nothing 4 http rest
m /api/items/1 4 rest
f / 2 bare rest
f /id/1?name=bun 2 bare rest
r /authorizations 2 rest gen
r /user/keys/id201 2 rest gen
EOF
    exit 0
fi

# run: tiers A to D through goose-http's bench/rest.sh, into OUT.
out=${OUT:-$root/bench/results/$(date -u +%Y-%m-%dT%H%M)-rest-$machine}
export OUT=$out MACHINE=$machine
mkdir -p "$out"
log=$out
if [ "${STEPS:-}" != none ]; then
    SERVERS=$servers "$gh/bench/rest.sh" run
else
    {
        echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "machine: $machine"
        echo "kernel: $(uname -r)"
        echo "cpu: $(lscpu | sed -n 's/^Model name: *//p'), $(nproc) logical CPUs"
        echo "server cpus: $server_cpus, workers: $workers, client cpus: $client_cpus, client threads: $threads"
        echo "duration: $duration s, warm-up: $warmup s, runs: $runs"
        echo "goose-http: $(git -C "$gh" rev-parse --short HEAD), goose: $(goose_version)"
        echo "cc: $(${CC:-cc} --version | head -1)"
        echo "rustc: $(rustc --version), zig: $(${ZIG:-zig} version)"
        echo "wrk: $(wrk -v 2>&1 | head -1)"
    } >"$out/env.txt"
fi
{
    echo "Plod: $(git -C "$root" rev-parse --short HEAD)$(git -C "$root" diff --quiet || echo ' (modified)')"
    echo "axum: $(sed -n '/^name = "axum"$/{n;s/version = //p;}' "$root/bench/rest/axum/Cargo.lock")," \
        "actix-web: $(sed -n '/^name = "actix-web"$/{n;s/version = //p;}' "$root/bench/rest/actix-web/Cargo.lock")," \
        "ntex: $(sed -n '/^name = "ntex"$/{n;s/version = //p;}' "$root/bench/rest/ntex/Cargo.lock")"
    echo "aegon: $(sed -n '/Aegon.git/{n;s/.*GIT_TAG \([0-9a-f]\{7\}\).*/\1/p;}' "$root/bench/rest/aegon/CMakeLists.txt")," \
        "glaze: $(sed -n '/glaze.git/{n;s/.*GIT_TAG //p;}' "$root/bench/rest/aegon/CMakeLists.txt")," \
        "aegon c++: $(${AEGON_CXX:-g++-16} --version | head -1)"
    # Aegon's buffers come from the huge-page pool when it has pages, which
    # VmRSS leaves out.
    echo "vm.nr_hugepages: $(cat /proc/sys/vm/nr_hugepages), memlock: $(ulimit -l)"
    echo "extra servers: $extra; tiers: $which"
} >>"$out/env.txt"

ticks() { awk '{print $14 + $15}' "/proc/$pid/stat"; }

wrk_() {
    taskset -c "$client_cpus" env LD_PRELOAD="$gh/build/bench/wrk-monotonic.so" \
        wrk --timeout 10s --latency "$@"
}

# One saturation cell: server $1, tier $2, the cell's name $3, wrk's script
# $4 and its argument $5.
cell() {
    s=$1 t=$2 name=$out/$3 script=$4 arg=$5
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ${name##*/}" | tee -a "$out/times.txt"
    start "$s" "$t" serialize pinned
    wrk_ -t "$threads" -c 256 -d "$warmup" -s "$script" "$url" -- "$arg" >/dev/null
    c0=$(ticks)
    wrk_ -t "$threads" -c 256 -d "$duration" -s "$script" "$url" -- "$arg" >"$name.wrk"
    echo "$c0 $(ticks) $hz $(awk '/^VmHWM/ {print $2}' "/proc/$pid/status")" >"$name.stat"
    halt
}

for t in $which; do
    for s in $(extra_of "$t"); do
        [ -x "$bin/$(binary "$s")" ] || { echo "bench/rest.sh: no server $s; run bench/rest.sh build"; exit 1; }
        start "$s" "$t" serialize free
        python3 "$tiers/check.py" "$port" "$t" "$data" >"$out/check-$s-$t.txt" 2>&1 ||
            { echo "bench/rest.sh: $s fails tier $t:"; tail -3 "$out/check-$s-$t.txt"; exit 1; }
        halt
    done
done

for run in $(seq "$runs"); do
    for t in $which; do
        for s in $(extra_of "$t"); do
            case $t in
            f)
                for route in root id json; do
                    cell "$s" f "x-f-$s-$route-r$run" "$tiers/tier-f.lua" "$route"
                done
                ;;
            r) cell "$s" r "x-r-$s-routes-r$run" "$tiers/tier-r.lua" "$tiers/github.txt" ;;
            m)
                cell "$s" a "x-m-$s-a-r$run" "$gh/bench/rest/tier-a.lua" "$data"
                cell "$s" m "x-m-$s-m-r$run" "$tiers/tier-m.lua" ""
                ;;
            esac
        done
    done
done

echo "results: $out"
python3 "$tiers/summary.py" "$out" | tee "$out/summary-extra.md"
