#!/bin/sh
# Runs HttpArena's own harness (MDA2AV/HttpArena, MIT) on this machine, with
# Plod's entry (bench/httparena/plod) beside HttpArena's entries, built from
# their own Dockerfiles. goose-http's bench/httparena.sh is the model; what
# it changes in the checkout, and why, holds here too:
#
#   bench/httparena.sh validate [FRAMEWORK]   scripts/validate.sh (default plod)
#   bench/httparena.sh run                    scripts/benchmark.sh, each framework
#                                             and profile, logs into OUT
#
# - Every profile's server cpuset, 0-31,64-95 on HttpArena's 128-thread
#   machine, becomes SERVER_CPUS (0-3), and so does each cpuset of the entry's
#   compose files, which the gateway profiles start.
# - The load generators run in Docker (LOADGEN_DOCKER) on LOAD_CPUS (4-15) with
#   THREADS (4) threads.
# - latency-1m offers LATENCY_RATE (200,000) requests per second instead of
#   1,000,000.
# - Under Docker Desktop, the readiness probe and the cgroup CPU reads run in
#   helper containers (bench/httparena/docker-desktop.sh).
# - On an arm64 Docker host, zrk's image takes zrk's aarch64-linux release.
#
# The harness needs bash 4 and GNU tools: on macOS, run this script in a Linux
# container that drives Docker Desktop through its socket, as goose-http's
# bench/README.md describes ("HttpArena under Docker on macOS").
#
# Settings, from the environment:
#   FRAMEWORKS  plod
#   PROFILES    baseline limited-conn latency-1m pipelined latency-10k async
#   SERVER_CPUS 0-3, LOAD_CPUS 4-15, and THREADS 4, as above
#   MACHINE     a short name for the machine (the host name), for OUT
#   RUNS 3 (the harness keeps the best), DURATION 5s,
#   OUT bench/results/httparena-<date>-<machine>
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cache=${CACHE:-$HOME/.cache/plod-bench}
arena=$cache/httparena
frameworks=${FRAMEWORKS:-plod}
profiles=${PROFILES:-baseline limited-conn latency-1m pipelined latency-10k async}
server_cpus=${SERVER_CPUS:-0-3}
machine=${MACHINE:-$(hostname -s)}
out=${OUT:-$root/bench/results/httparena-$(date -u +%Y-%m-%dT%H%M)-$machine}
case $out in /*) ;; *) out=$PWD/$out ;; esac

HTTPARENA_COMMIT=3717e256e9e4c1783f040c126341c5c4a11abe42
GCANNON_COMMIT=11c802b2bdfe9af2fac4ac2571ae2de4c530cc62
# zrk-2.3.0-aarch64-linux.tar.gz's SHA-256, from the release's SHA256SUMS.txt.
ZRK_ARM64_SHA256=361f2632e3cee672cf6a8676438c9fa93e8a5702a0007bacc266861767bab213

if [ ! -d "$arena/.git" ]; then
    git clone -q https://github.com/MDA2AV/HttpArena.git "$arena"
fi
git -C "$arena" fetch -q origin
git -C "$arena" checkout -q -f "$HTTPARENA_COMMIT"
git -C "$arena" clean -q -fdx frameworks/plod scripts

entry=$arena/frameworks/plod
rm -rf "$entry"
cp -r "$root/bench/httparena/plod" "$entry"
mkdir -p "$entry/src/bench/httparena/plod" "$entry/src/scripts"
cp "$root"/*.goose "$entry/src/"
cp "$root"/bench/httparena/plod/*.goose "$entry/src/bench/httparena/plod/"
cp "$root/scripts/goose.sh" "$entry/src/scripts/"
sed -i "s/0-31,64-95/$server_cpus/g" "$arena/scripts/lib/profiles.sh"
sed -i "s/^\( *cpuset:\).*/\1 \"$server_cpus\"/" "$entry"/compose.*.yml
if docker info --format '{{.OperatingSystem}}' | grep -q 'Docker Desktop'; then
    sed -i 's|if curl -sk -o /dev/null --max-time 2 |if docker run --rm --network host curlimages/curl:8.11.1 -sk -o /dev/null --max-time 2 |' \
        "$arena/scripts/lib/framework.sh"
    cat "$root/bench/httparena/docker-desktop.sh" >>"$arena/scripts/lib/stats.sh"
fi
if [ "$(docker info --format '{{.Architecture}}')" = aarch64 ]; then
    sed -i -e 's/x86_64-linux\.tar\.gz/aarch64-linux.tar.gz/' \
        -e "s/^ARG ZRK_SHA256=.*/ARG ZRK_SHA256=$ZRK_ARM64_SHA256/" "$arena/docker/zrk.Dockerfile"
fi

export LOADGEN_DOCKER=true SKIP_TUNE=true
export GCANNON_CPUS=${LOAD_CPUS:-4-15} THREADS=${THREADS:-4}
export ZRK_RATE_LATENCY_1M=${LATENCY_RATE:-200000}
export RUNS=${RUNS:-3} DURATION=${DURATION:-5s}

docker build -q --build-arg GCANNON_REF="$GCANNON_COMMIT" -t gcannon:latest \
    -f "$arena/docker/gcannon.Dockerfile" "$arena/docker" >/dev/null

cd "$arena"
case ${1:-} in
validate)
    ./scripts/validate.sh "${2:-plod}"
    ;;
run)
    mkdir -p "$out"
    {
        echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "machine: $machine"
        echo "kernel: $(uname -r)"
        echo "cpu: $(lscpu | sed -n 's/^Model name: *//p'), $(nproc) logical CPUs"
        echo "httparena: $HTTPARENA_COMMIT, gcannon: $GCANNON_COMMIT"
        echo "plod: $(git -C "$root" rev-parse --short HEAD)$(git -C "$root" diff --quiet || echo ' (modified)')"
        echo "server cpus: $server_cpus, load cpus: $GCANNON_CPUS, threads: $THREADS"
        echo "runs: $RUNS, duration: $DURATION, latency-1m rate: $ZRK_RATE_LATENCY_1M"
        echo "docker: $(docker version --format '{{.Server.Version}}')"
    } >"$out/env.txt"
    for fw in $frameworks; do
        for p in $profiles; do
            echo "$fw $p"
            ./scripts/benchmark.sh "$fw" "$p" >"$out/$fw-$p.log" 2>&1 || echo "$fw $p: failed"
        done
    done
    echo "results: $out"
    ;;
*)
    echo "usage: bench/httparena.sh validate [FRAMEWORK] | run"
    exit 2
    ;;
esac
