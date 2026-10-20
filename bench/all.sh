#!/bin/sh
# The nightly session: measures goose-http's and goose-rest's Goose servers,
# unattended, with no competitor, whose cells come from earlier runs. In order:
#
#   1. Preparation: the tools, both checkouts brought to origin/main where they
#      can be, the pinned Goose compiler, and an idle machine.
#   2. Both repositories' scripts/test.sh.
#   3. The Goose builds: goose-http's bench/build.sh and this repository's
#      bench/rest.sh build, with ONLY=goose.
#   4. This repository's bench/rest.sh check.
#   5. goose-http's bench/run.sh and bench/files.sh.
#   6. This repository's bench/rest.sh run: goose-http's tiers A to D and
#      tiers F, R, and M, on goose-http alone and goose-rest.
#   7. As root: goose-http's bench/instructions.sh, and bench/rest.sh count.
#
# It stops only when nothing can be measured: a tool missing, or no compiler.
# Anything else is a warning that the session records and goes on past: a
# checkout with local changes or off origin/main, goose-http's code apart
# from the tag rest.goose pins, a machine that won't go idle, failing tests,
# or no root for the counts. A step that fails is recorded, and the steps
# after it run unless they need its output. The terminal gets a line per step
# and per warning; the commands' output goes to the session's log.
#
# About 2 h 40 min on the desktop. Under one time stamp, goose-http's runs go
# to its bench/results/, the REST run to this repository's bench/results/, and
# the session's progress, warnings, log, and environment to
# build/bench-all/<stamp>-<machine>/, with manifest.txt saying what ran, how
# it ended, and where each result is; build/bench-all/latest names the newest
# session. Nothing is committed: writing the results up is a separate step.
#
# Settings, from the environment, beside each script's own:
#   GOOSE_HTTP   a goose-http checkout (default: ../goose-http beside this one)
#   GOOSE        the Goose compiler for both repositories (default: the pin,
#                scripts/goose.sh)
#   PULL         0 leaves both checkouts as they are; by default a clean one
#                behind origin/main is fast-forwarded to it
#   TESTS        0 skips the test suites
#   RATE_A, RATE_B, RATE_C   tiers A to C's fixed rates, 100000, 24000, and
#                1700, the full run of 2026-10-13's, so cells compare across
#                sessions
#   REUSE        passed on to bench/run.sh, to copy competitor cells into its
#                summary
#   MACHINE      the host name
#   IDLE_LOAD    the highest 1-minute load average counted idle (0.5), and on
#                WSL, IDLE_CPU the highest Windows CPU load in percent (10);
#                IDLE_WAIT the minutes to wait for both (15)
#   DRY          1 prepares and names each step without running it, nor
#                waiting for an idle machine
#   HEARTBEAT    seconds between progress lines during a step (600): its time
#                so far, the last session's time for it, and for the runs that
#                note them, the cell being measured
set -u

# Run from a copy in the session's directory: pulling this checkout would
# otherwise change the script while sh reads it.
if [ -z "${BENCH_ALL_ROOT:-}" ]; then
    BENCH_ALL_ROOT=$(cd "$(dirname "$0")/.." && pwd)
    copy=$(mktemp)
    cp "$0" "$copy"
    BENCH_ALL_ROOT=$BENCH_ALL_ROOT exec sh "$copy" "$@"
fi
root=$BENCH_ALL_ROOT
machine=${MACHINE:-$(hostname -s)}
stamp=$(date -u +%Y-%m-%dT%H%M)
log=$root/build/bench-all/$stamp-$machine
mkdir -p "$log"
mv "$0" "$log/all.sh"
previous=$(cat "$root/build/bench-all/latest" 2>/dev/null || true)
if [ "${DRY:-}" != 1 ]; then echo "$stamp-$machine" >"$root/build/bench-all/latest"; fi
: >"$log/status.txt"

say() { echo "$(date -u +%H:%M:%SZ) $*" | tee -a "$log/progress.txt"; }
warn() { echo "$*" >>"$log/warnings.txt"; say "warning: $*"; }
stop() { say "stopped: $*"; echo "stopped: $*" >>"$log/warnings.txt"; manifest; exit 1; }

# 1 h 05 min, or 4 min 12 s.
span() {
    if [ "$1" -ge 3600 ]; then printf '%d h %02d min' $(($1 / 3600)) $(($1 % 3600 / 60))
    else printf '%d min %02d s' $(($1 / 60)) $(($1 % 60)); fi
}

# The seconds step $1 took in the previous session, if it ran.
estimate() {
    awk -F'\t' -v s="$1" '$1 == s && $2 == "ok" { print $4 }' \
        "$root/build/bench-all/$previous/status.txt" 2>/dev/null | head -1
}

status_of() { awk -F'\t' -v s="$1" '$1 == s { print $2 }' "$log/status.txt" | tail -1; }

# Says every HEARTBEAT seconds that step $1, begun at $2, is still running,
# with the last cell named in times.txt $3 when there is one.
heartbeat() {
    while sleep "${HEARTBEAT:-600}"; do
        cell=
        if [ -n "$3" ] && [ -s "$3" ]; then cell=", at $(tail -1 "$3" | cut -d' ' -f2)"; fi
        say "[$steps/$total] $1: running, $(span $(($(date +%s) - $2)))${est:+ of about $(span "$est")}$cell"
    done
}

# Runs step $1 with the command after $3, unless step $2 didn't end ok, and
# records how it ended. Its output goes to the log. TIMES names the
# times.txt its cells are noted in, if any.
steps=0 total=10
run_step() {
    name=$1 need=$2
    shift 2
    steps=$((steps + 1))
    if [ -n "$need" ] && [ "$(status_of "$need")" != ok ]; then
        printf '%s\tskipped\tneeds %s\t0\n' "$name" "$need" >>"$log/status.txt"
        say "[$steps/$total] $name: skipped, as $need didn't succeed"
        return
    fi
    est=$(estimate "$name")
    say "[$steps/$total] $name${est:+, about $(span "$est")}"
    echo "==== $(date -u +%Y-%m-%dT%H:%M:%SZ) $name" >>"$log/session.log"
    t0=$(date +%s)
    heartbeat "$name" "$t0" "${TIMES:-}" &
    beat=$!
    if [ "${DRY:-}" = 1 ]; then st=ok
    elif ("$@") >>"$log/session.log" 2>&1; then st=ok; else st=failed; fi
    kill $beat 2>/dev/null
    wait $beat 2>/dev/null
    TIMES=
    dt=$(($(date +%s) - t0))
    printf '%s\t%s\t%s\t%d\n' "$name" "$st" "$(span $dt)" "$dt" >>"$log/status.txt"
    say "[$steps/$total] $name: $st after $(span $dt)"
}

manifest() {
    {
        echo "bench/all.sh session $stamp-$machine"
        echo
        cat "$log/env.txt" 2>/dev/null
        echo
        echo "Steps:"
        awk -F'\t' '{ printf "  %-28s %-8s %s\n", $1, $2, $3 }' "$log/status.txt"
        echo
        echo "Warnings:"
        if [ -s "$log/warnings.txt" ]; then sed 's/^/  /' "$log/warnings.txt"; else echo "  none"; fi
        echo
        echo "Results:"
        for d in "${results:-}/$stamp-$machine" "${results:-}/$stamp-$machine-files" \
            "$root/bench/results/$stamp-rest-$machine"; do
            if [ -d "$d" ]; then echo "  $d"; fi
        done
        echo "  $log (progress, warnings, session.log)"
    } >"$log/manifest.txt"
}

as_root() {
    # Name each variable: sudo may refuse -E and keep none of them.
    if [ "$(id -u)" = 0 ]; then "$@"; else
        sudo -n env PATH="$PATH" GOOSE="$GOOSE" GOOSE_HTTP="$GOOSE_HTTP" MACHINE="$MACHINE" "$@"
    fi
}

windows_cpu() {
    powershell.exe -NoProfile -Command \
        "(Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average" |
        tr -d '\r'
}

# Idle when two checks 30 s apart both pass, within IDLE_WAIT minutes.
wait_idle() {
    passed=0 tries=0 limit=$((${IDLE_WAIT:-15} * 2))
    while [ $passed -lt 2 ]; do
        load=$(cut -d' ' -f1 /proc/loadavg)
        cpu=-
        command -v powershell.exe >/dev/null && cpu=$(windows_cpu)
        if awk -v l="$load" -v c="$cpu" -v ml="${IDLE_LOAD:-0.5}" -v mc="${IDLE_CPU:-10}" \
            'BEGIN { exit !(l <= ml && (c == "-" || c <= mc)) }'; then
            passed=$((passed + 1))
        else
            passed=0
        fi
        tries=$((tries + 1))
        [ $tries -eq 1 ] && [ $passed -eq 0 ] && say "waiting for an idle machine: load $load, Windows CPU $cpu%"
        if [ $tries -ge $limit ]; then
            warn "not idle after ${IDLE_WAIT:-15} min (load $load, Windows CPU $cpu%); measuring anyway"
            return
        fi
        [ $passed -ge 2 ] || sleep 30
    done
    say "idle: load $load, Windows CPU $cpu%"
}

# Brings checkout $1 to origin/main if it's clean and behind, and warns when
# it's measured as something else.
sync_repo() {
    name=$(basename "$1")
    git -C "$1" fetch -q origin || { warn "$name: fetch failed; measuring it as it is"; return; }
    head=$(git -C "$1" rev-parse HEAD) main=$(git -C "$1" rev-parse origin/main)
    if ! git -C "$1" diff --quiet HEAD; then
        warn "$name has uncommitted changes, measured with them"
    elif [ "$head" = "$main" ]; then
        :
    elif [ "${PULL:-1}" != 0 ] && git -C "$1" merge-base --is-ancestor HEAD origin/main; then
        git -C "$1" merge -q --ff-only origin/main && say "$name: pulled to $(git -C "$1" rev-parse --short HEAD)"
    else
        warn "$name is at $(git -C "$1" rev-parse --short HEAD), not origin/main $(git -C "$1" rev-parse --short origin/main)"
    fi
}

say "session $stamp-$machine: progress here, details in $log"

# 1. Preparation.
gh=${GOOSE_HTTP:-$root/../goose-http}
[ -d "$gh/.git" ] || stop "no goose-http checkout at $gh; set GOOSE_HTTP"
gh=$(cd "$gh" && pwd)
results=$gh/bench/results
for tool in git gcc python3 nc taskset wrk h2load curl sha256sum; do
    command -v $tool >/dev/null || stop "no $tool"
done
counts=yes
command -v perf >/dev/null || { warn "no perf: the instruction counts are skipped"; counts=; }
[ -z "$counts" ] || as_root true 2>/dev/null ||
    { warn "no root, and sudo asks for a password: the instruction counts are skipped"; counts=; }
sync_repo "$root"
sync_repo "$gh"
. "$root/scripts/goose.sh" >>"$log/session.log" 2>&1 || stop "the pinned Goose compiler didn't build; see session.log"
GOOSE=$(cd "$(dirname "$GOOSE")" && pwd)/$(basename "$GOOSE")
[ -x "$GOOSE" ] || stop "GOOSE isn't executable: $GOOSE"
export GOOSE GOOSE_HTTP=$gh MACHINE=$machine
export RATE_A=${RATE_A:-100000} RATE_B=${RATE_B:-24000} RATE_C=${RATE_C:-1700}
# goose-rest builds against the pinned goose-http; goose-http's measured build
# is its HEAD. Scripts, tests, and records may differ.
ref=$(sed -n 's/^import http from .*goose-http@\([^"]*\)".*/\1/p' "$root/rest.goose" | head -1)
git -C "$gh" diff --quiet "$ref" HEAD -- . ':!bench/results' ':!bench/*.sh' ':!test' ':!*.md' 2>/dev/null ||
    warn "goose-http's code differs from $ref, which goose-rest pins: goose-http alone and goose-rest measure different goose-http"
[ "${DRY:-}" = 1 ] || wait_idle
{
    echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "machine: $machine"
    echo "kernel: $(uname -r)"
    echo "cpu: $(lscpu | sed -n 's/^Model name: *//p'), $(nproc) logical CPUs"
    command -v wsl.exe >/dev/null && echo "wsl: $(wsl.exe --version | iconv -f UTF-16LE -t UTF-8 | tr -d '\r' | head -1)"
    echo "goose-rest: $(git -C "$root" rev-parse --short HEAD)$(git -C "$root" diff --quiet HEAD || echo ' (modified)'), goose-http: $(git -C "$gh" rev-parse --short HEAD)$(git -C "$gh" diff --quiet HEAD || echo ' (modified)') (pinned: $ref)"
    echo "goose: $(goose_version), $GOOSE, sha256 $(sha256sum <"$GOOSE" | cut -d' ' -f1)"
    echo "gcc: $(gcc --version | head -1)"
    echo "rates: A $RATE_A, B $RATE_B, C $RATE_C; reuse: ${REUSE:-none}"
} >"$log/env.txt"

# 2 to 7.
rest_servers="goose-uring goose-epoll goose-uring-rest goose-epoll-rest"
rest_extra="goose-uring-rest goose-epoll-rest"
tests() { cd "$1" && scripts/test.sh; }
http_build() { cd "$gh" && ONLY=goose bench/build.sh; }
rest_build() { cd "$root" && ONLY=goose bench/rest.sh build; }
check() {
    (cd "$root" && SERVERS=$rest_servers EXTRA=$rest_extra bench/rest.sh check) | tee "$log/check.txt"
    ! grep -q FAIL "$log/check.txt"
}
http_run() { cd "$gh" && SERVERS="goose goose-uring" OUT="$results/$stamp-$machine" bench/run.sh; }
http_files() {
    cd "$gh" && SERVERS="goose goose-uring goose-uring-epoll" OUT="$results/$stamp-$machine-files" bench/files.sh
}
rest_run() {
    cd "$root" && SERVERS=$rest_servers EXTRA=$rest_extra OUT="$root/bench/results/$stamp-rest-$machine" \
        bench/rest.sh run
}
# set -o pipefail isn't POSIX: each count goes to a file, then to the log.
http_counts() {
    cd "$gh" && as_root bench/instructions.sh goose goose-uring >"$log/instructions.txt" 2>&1
    st=$?
    cat "$log/instructions.txt"
    return $st
}
rest_counts() {
    cd "$root" && as_root bench/rest.sh count >"$log/count.txt" 2>&1
    st=$?
    cat "$log/count.txt"
    return $st
}
if [ "${TESTS:-1}" != 0 ]; then
    run_step "goose-http tests" "" tests "$gh"
    run_step "goose-rest tests" "" tests "$root"
    for s in "goose-http tests" "goose-rest tests"; do
        [ "$(status_of "$s")" = ok ] || warn "$s failed; the servers are measured anyway (session.log)"
    done
else
    total=$((total - 2))
    say "tests skipped (TESTS=0)"
fi
run_step "goose-http build" "" http_build
run_step "goose-rest build" "" rest_build
run_step "REST check" "goose-rest build" check
run_step "goose-http run.sh" "goose-http build" http_run
run_step "goose-http files.sh" "goose-http build" http_files
TIMES=$root/bench/results/$stamp-rest-$machine/times.txt
run_step "REST run" "REST check" rest_run
if [ -n "$counts" ]; then
    run_step "goose-http instructions" "goose-http build" http_counts
    run_step "REST count" "goose-rest build" rest_counts
else
    total=$((total - 2))
fi

# Each result beside the others of its run, as the write-ups cite them.
if [ -d "$results/$stamp-$machine" ]; then
    cp "$log/env.txt" "$results/$stamp-$machine/session-env.txt"
    cut -f1-3 "$log/status.txt" >"$results/$stamp-$machine/session-steps.txt"
    if [ -s "$log/instructions.txt" ]; then cp "$log/instructions.txt" "$results/$stamp-$machine/"; fi
fi
if [ -d "$root/bench/results/$stamp-rest-$machine" ] && [ -s "$log/count.txt" ]; then
    cp "$log/count.txt" "$root/bench/results/$stamp-rest-$machine/count.txt"
fi

manifest
failed=$(awk -F'\t' '$2 != "ok" { n++ } END { print n + 0 }' "$log/status.txt")
warned=0
if [ -s "$log/warnings.txt" ]; then warned=$(wc -l <"$log/warnings.txt" | tr -d ' '); fi
say "done: $((steps - failed)) of $steps steps ok, $warned warnings; $log/manifest.txt"
[ "$failed" = 0 ]
