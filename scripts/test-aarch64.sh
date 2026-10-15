#!/bin/sh
# Cross-builds every example for aarch64 Linux, then runs
# scripts/test-examples.sh on the builds in an arm64 container, and prints
# each example's peak RSS. goose-http's scripts/test-aarch64.sh does the same
# for goose-http, and its docs/embedded.md covers building for a board.
#
# The builds run in an amd64 container and the checks in an arm64 one, so
# Docker emulates one of them: arm64 on an x86-64 host, amd64 on an arm64
# host. Docker Desktop has both, and elsewhere tonistiigi/binfmt installs
# them.
#
# GOOSE names a Linux build of the compiler that runs in ubuntu:26.04 for
# amd64, beside its stdlib or in its checkout. Without it, the script uses the
# pinned release's linux-x64 archive (scripts/goose.sh), or with GOOSE_COMMIT
# that commit, built in the amd64 container into build/aarch64/goose/.
# GOOSE_HTTP names a goose-http checkout:
# with it, the script also cross-builds that checkout's examples/device at
# its HEAD and prints its peak RSS on one worker, for comparison.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/build/aarch64
mkdir -p "$out/examples" "$out/goose-home"

docker build -q --platform linux/amd64 -t goose-rest-cross-aarch64 - >/dev/null <<'EOF'
FROM ubuntu:26.04
# arm64 packages come from Ubuntu's ports archive, for liburing-dev:arm64.
RUN sed -i 's/^Types: deb$/Types: deb\nArchitectures: amd64/' /etc/apt/sources.list.d/ubuntu.sources && \
    . /etc/os-release && \
    printf 'Types: deb\nURIs: http://ports.ubuntu.com/ubuntu-ports\nSuites: %s %s-updates\nComponents: main universe\nArchitectures: arm64\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' \
        "$VERSION_CODENAME" "$VERSION_CODENAME" >/etc/apt/sources.list.d/arm64.sources && \
    dpkg --add-architecture arm64 && apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gcc-aarch64-linux-gnu liburing-dev:arm64 \
        git ca-certificates cmake g++ make >/dev/null
EOF
docker build -q --platform linux/arm64 -t goose-rest-run-arm64 - >/dev/null <<'EOF'
FROM ubuntu:26.04
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq liburing2 curl >/dev/null
EOF

# The compiler: GOOSE's, the release's, or GOOSE_COMMIT's built in the
# container. Its own root keeps that build apart from a host one of the same
# commit in build/.
if [ -z "${GOOSE:-}" ]; then
    if [ -n "${GOOSE_COMMIT:-}" ]; then
        mkdir -p "$out/goose"
        GOOSE=$(docker run --rm --platform linux/amd64 --user "$(id -u):$(id -g)" -v "$root:$root" \
            -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*' \
            -e root="$out/goose" -e GOOSE_COMMIT -e HOME="$out" goose-rest-cross-aarch64 \
            sh "$root/scripts/goose.sh")
    else
        GOOSE=$(GOOSE_ASSET=linux-x64 "$root/scripts/goose.sh")
    fi
fi
goose=$(cd "$(dirname "$GOOSE")" && pwd)/$(basename "$GOOSE")
# The compiler finds its stdlib beside it or in its checkout, which the
# container mounts.
checkout=$(dirname "$(dirname "$goose")")

# goose-http's device, from a copy of the checkout's HEAD under build/.
if [ -n "${GOOSE_HTTP:-}" ]; then
    gh=$out/goose-http
    rm -rf "$gh"
    mkdir -p "$gh"
    git -C "$GOOSE_HTTP" archive HEAD | tar -x -C "$gh"
    git -C "$GOOSE_HTTP" rev-parse --short HEAD >"$gh/COMMIT"
fi

echo "cross-building the examples into $out/examples"
# The compiler fetches goose-http with git, which refuses a mounted directory
# whose owner it doesn't recognize, as on Docker Desktop for macOS.
docker run --rm --platform linux/amd64 --user "$(id -u):$(id -g)" \
    -v "$root:$root" -v "$checkout:$checkout" -w "$root" \
    -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*' \
    -e GOOSE="$goose" -e GOOSE_HOME="$out/goose-home" -e HOME="$out" -e BIN="$out/examples" \
    -e GH="${gh:-}" goose-rest-cross-aarch64 sh -c '
set -eu
aarch64-linux-gnu-gcc --version | head -1
for dir in examples/*/; do
    name=$(basename "$dir")
    "$GOOSE" build --cc /usr/bin/aarch64-linux-gnu-gcc -o "$BIN/$name" "${dir}main.goose" >"$BIN/$name.build.log" 2>&1 ||
        { cat "$BIN/$name.build.log"; echo "FAIL: $name does not build for aarch64"; exit 1; }
done
if [ -n "$GH" ]; then
    "$GOOSE" build --cc /usr/bin/aarch64-linux-gnu-gcc -o "$GH/device" "$GH/examples/device/device.goose" \
        >"$GH/device.build.log" 2>&1 ||
        { cat "$GH/device.build.log"; echo "FAIL: goose-http'\''s device does not build for aarch64"; exit 1; }
fi'

echo "running them on arm64"
docker run --rm --platform linux/arm64 --user "$(id -u):$(id -g)" -v "$root:$root" -w "$root" \
    -e PREBUILT=1 -e RSS=1 -e BIN="$out/examples" -e GH="${gh:-}" goose-rest-run-arm64 sh -c '
set -eu
uname -srm
sh scripts/test-examples.sh
[ -n "$GH" ] || exit 0
# goose-http'\''s device on one worker, as goose-rest'\''s serves, after the
# requests goose-http'\''s scripts/test-examples.sh makes of it.
sys=$BIN/device-sys
for loop in uring epoll; do
    echo
    echo "== goose-http $(cat "$GH/COMMIT") device, LOOP=$loop"
    THERMAL=$sys/zone LED=$sys/led LOOP=$loop WORKERS=1 "$GH/device" >"$GH/device.log" 2>&1 &
    pid=$!
    until curl -s -o /dev/null http://127.0.0.1:8080/api/status; do sleep 0.1; done
    start=$(sed -n "s/^VmHWM:[[:space:]]*//p" "/proc/$pid/status")
    curl -sf -o /dev/null http://127.0.0.1:8080/
    curl -sf -o /dev/null -X PUT http://127.0.0.1:8080/api/led/on
    curl -sf -o /dev/null -X PUT http://127.0.0.1:8080/api/gpio/on
    curl -sf -o /dev/null -X PUT http://127.0.0.1:8080/api/led/off
    curl -sf -o /dev/null -N "http://127.0.0.1:8080/api/events?n=2&ms=100"
    echo "device: peak RSS $start at start, $(sed -n "s/^VmHWM:[[:space:]]*//p" "/proc/$pid/status") after the checks"
    kill "$pid"
    wait "$pid" 2>/dev/null || true
done'
