#!/bin/sh
# Measures goose-http's and goose-rest's Goose servers in one unattended
# session, with no competitor: their cells come from earlier runs, which
# take longer and want a closer look. In order, stopping at the first failure:
#
#   1. Checks: the tools, root through sudo without a password, both
#      checkouts clean and at origin/main, goose-http's code the same as at
#      the tag rest.goose pins, and an idle machine.
#   2. Both repositories' scripts/test.sh.
#   3. The Goose builds alone: goose-http's bench/build.sh and this
#      repository's bench/rest.sh build, with ONLY=goose.
#   4. goose-http's bench/run.sh and bench/files.sh on its Goose builds.
#   5. This repository's bench/rest.sh check and run: goose-http's tiers A to
#      D and tiers F, R, and M, on goose-http alone and goose-rest.
#   6. As root: goose-http's bench/instructions.sh, and bench/rest.sh count.
#
# About 2 h 30 min on the desktop. The results go to goose-http's
# bench/results/, under one time stamp, and this session's log, step times,
# and environment to build/bench-all/<stamp>-<machine>/. Nothing is
# committed: the write-up is a separate step.
#
# Settings, from the environment, beside each script's own:
#   GOOSE        the Goose compiler; required
#   GOOSE_HTTP   goose-http's checkout, ../goose-http
#   RATE_A, RATE_B, RATE_C   tiers A to C's fixed rates, 100000, 24000, and
#                1700, the full run of 2026-10-13's: step 1's default would
#                set them from Goose alone, and its cells couldn't be compared
#   REUSE        passed on to bench/run.sh, to copy competitor cells into its
#                summary
#   MACHINE      the host name
#   IDLE_LOAD    the highest 1-minute load average the checks accept (0.5),
#                and on WSL, IDLE_CPU the highest Windows CPU load in percent
#                (10)
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
gh=$(cd "${GOOSE_HTTP:-$root/../goose-http}" && pwd)
: "${GOOSE:?bench/all.sh: set GOOSE to the Goose compiler}"
GOOSE=$(cd "$(dirname "$GOOSE")" && pwd)/$(basename "$GOOSE")
machine=${MACHINE:-$(hostname -s)}
stamp=$(date -u +%Y-%m-%dT%H%M)
log=$root/build/bench-all/$stamp-$machine
results=$gh/bench/results
export GOOSE GOOSE_HTTP=$gh MACHINE=$machine
export RATE_A=${RATE_A:-100000} RATE_B=${RATE_B:-24000} RATE_C=${RATE_C:-1700}
mkdir -p "$log"

current=checks
step() {
    current=$1
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $current" | tee -a "$log/steps.txt"
}

as_root() {
    if [ "$(id -u)" = 0 ]; then "$@"; else sudo -n -E env PATH="$PATH" "$@"; fi
}

windows_cpu() {
    powershell.exe -NoProfile -Command \
        "(Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average" |
        tr -d '\r'
}

# The machine is idle when two checks 30 s apart both pass; it has 10 min.
wait_idle() {
    passed=0 tries=0
    while [ $passed -lt 2 ]; do
        load=$(cut -d' ' -f1 /proc/loadavg)
        cpu=-
        command -v powershell.exe >/dev/null && cpu=$(windows_cpu)
        echo "idle check: load $load, Windows CPU $cpu%"
        if awk -v l="$load" -v c="$cpu" -v ml="${IDLE_LOAD:-0.5}" -v mc="${IDLE_CPU:-10}" \
            'BEGIN { exit !(l <= ml && (c == "-" || c <= mc)) }'; then
            passed=$((passed + 1))
        else
            passed=0
        fi
        tries=$((tries + 1))
        [ $tries -lt 20 ] || { echo "bench/all.sh: the machine isn't idle"; return 1; }
        [ $passed -ge 2 ] || sleep 30
    done
}

# Repository $1 has no change to a tracked file, and is at origin/main.
check_repo() {
    git -C "$1" diff --quiet HEAD ||
        { echo "bench/all.sh: $1 has uncommitted changes"; return 1; }
    git -C "$1" fetch -q origin
    [ "$(git -C "$1" rev-parse HEAD)" = "$(git -C "$1" rev-parse origin/main)" ] ||
        { echo "bench/all.sh: $1 isn't at origin/main; pull or push first"; return 1; }
}

session() {
    step checks
    for tool in git gcc python3 nc taskset perf wrk h2load curl sha256sum; do
        command -v $tool >/dev/null || { echo "bench/all.sh: no $tool"; return 1; }
    done
    [ -x "$GOOSE" ] || { echo "bench/all.sh: GOOSE isn't executable: $GOOSE"; return 1; }
    as_root true || { echo "bench/all.sh: sudo asks for a password; run as root"; return 1; }
    check_repo "$root"
    check_repo "$gh"
    # goose-rest builds against the pinned tag; goose-http's measured build is
    # its HEAD, so they must be the same code. Scripts and records may differ.
    ref=$(sed -n 's/^import http from .*goose-http@\([^"]*\)".*/\1/p' "$root/rest.goose" | head -1)
    git -C "$gh" diff --quiet "$ref" HEAD -- . ':!bench/results' ':!bench/*.sh' ':!*.md' ||
        { echo "bench/all.sh: goose-http's code differs from $ref; tag a release and move the pin"; return 1; }
    wait_idle
    {
        echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "machine: $machine"
        echo "kernel: $(uname -r)"
        echo "cpu: $(lscpu | sed -n 's/^Model name: *//p'), $(nproc) logical CPUs"
        command -v wsl.exe >/dev/null && echo "wsl: $(wsl.exe --version | iconv -f UTF-16LE -t UTF-8 | tr -d '\r' | head -1)"
        echo "goose-rest: $(git -C "$root" rev-parse --short HEAD), goose-http: $(git -C "$gh" rev-parse --short HEAD) (code as $ref)"
        echo "goose: $GOOSE, sha256 $(sha256sum <"$GOOSE" | cut -d' ' -f1)"
        echo "gcc: $(gcc --version | head -1)"
        echo "rates: A $RATE_A, B $RATE_B, C $RATE_C; reuse: ${REUSE:-none}"
        echo "results: $results/$stamp-$machine, $stamp-$machine-files, $stamp-rest-$machine"
    } | tee "$log/env.txt"

    step "goose-http tests"
    (cd "$gh" && scripts/test.sh)
    step "goose-rest tests"
    (cd "$root" && scripts/test.sh)

    step "goose builds"
    (cd "$gh" && ONLY=goose bench/build.sh)
    (cd "$root" && ONLY=goose bench/rest.sh build)

    step "goose-http bench/run.sh"
    (cd "$gh" && SERVERS="goose goose-uring" OUT="$results/$stamp-$machine" bench/run.sh)
    step "goose-http bench/files.sh"
    (cd "$gh" && SERVERS="goose goose-uring goose-uring-epoll" OUT="$results/$stamp-$machine-files" bench/files.sh)

    step "goose-rest bench/rest.sh check"
    export SERVERS="goose-uring goose-epoll goose-uring-rest goose-epoll-rest"
    export EXTRA="goose-uring-rest goose-epoll-rest"
    (cd "$root" && bench/rest.sh check)
    step "goose-rest bench/rest.sh run"
    (cd "$root" && OUT="$results/$stamp-rest-$machine" bench/rest.sh run)
    unset SERVERS EXTRA

    step "goose-http bench/instructions.sh"
    (cd "$gh" && as_root bench/instructions.sh goose goose-uring >"$log/instructions.txt" 2>&1)
    cat "$log/instructions.txt"
    step "goose-rest bench/rest.sh count"
    (cd "$root" && as_root bench/rest.sh count >"$log/count.txt" 2>&1)
    cat "$log/count.txt"
    step done
}

# The session's output goes to its log as well, and its last line says
# whether it finished.
(
    trap 'status=$?; [ "$current" = done ] || echo "bench/all.sh: failed in $current (exit $status)" | tee -a "$log/steps.txt"' EXIT
    session
) 2>&1 | tee "$log/session.log"
grep -q ' done$' "$log/steps.txt"
