#!/bin/sh
# Runs every test this repository has, and fails on the first failure: the
# typecheck of each root file under test/, the unit tests through TinyCC
# (scripts/test-unit.sh), the generator's output for each schema under
# test/gen/ and examples/ against its golden file, each example served and
# requested (scripts/test-examples.sh), then each spike, whose output must match the
# expected.txt beside it, the output its README records; a spike that spawns
# a thread is built with goose build first. Spike 04's -O2 C must
# also keep main as its only Goose function: everything else inlined. And
# test/inline_route.goose's -O2 C must keep none of its middleware,
# rest::route, or the functions that fail, all inlined into the handler: only
# the handler and library leaves stay functions.
#
# GOOSE names the compiler (default: goose on PATH).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
goose=${GOOSE:-goose}

step() {
    echo
    echo "== $*"
}

for f in "$root"/test/*.goose; do
    step "check ${f#"$root"/}"
    "$goose" check "$f"
done

step "test-unit.sh"
"$root/scripts/test-unit.sh"

# Golden files: what the generator writes from each schema must match the
# committed source byte for byte. test_gen.goose, among the unit tests,
# compiles one and round-trips JSON through it.
mkdir -p "$root/build/gen"
for f in "$root"/test/gen/*.json "$root"/examples/*/api.json; do
    name=$(basename "$f" .json)
    dir=$(dirname "$f")
    step "gen ${f#"$root"/}"
    "$goose" "$root/gen/main.goose" -- gen "$f" -o "$root/build/gen/${name}_gen.goose"
    diff -u "$dir/${name}_gen.goose" "$root/build/gen/${name}_gen.goose"
done

step "test-examples.sh"
"$root/scripts/test-examples.sh"

mkdir -p "$root/build"
for f in "$root"/spikes/*/main.goose "$root"/spikes/*/*/main.goose; do
    step "spike ${f#"$root"/}"
    # TinyCC can't run threads: a spike that spawns one is built and run.
    if grep -q thread_spawn "$f"; then
        "$goose" build -o "$root/build/spike" "$f"
        "$root/build/spike" >"$root/build/spike.out"
    else
        "$goose" "$f" >"$root/build/spike.out"
    fi
    diff -u "$(dirname "$f")/expected.txt" "$root/build/spike.out"
done

step "spike 04's C"
"$goose" -O2 -o "$root/build/spike04.c" "$root/spikes/04-inlining/main.goose"
fns=$(grep -E '^static .*_g[0-9]*\(' "$root/build/spike04.c" | grep -v ';' | sed 's/(.*//; s/.* //')
if [ "$fns" != main_g ]; then
    echo "spike 04: expected only main_g, got:" $fns
    exit 1
fi

step "inline_route's C"
"$goose" -O2 -o "$root/build/inline_route.c" "$root/test/inline_route.goose"
fns=$(grep -E '^static .*_g[0-9]*\(' "$root/build/inline_route.c" | grep -v ';' | sed 's/(.*//; s/.* //')
kept=$(echo "$fns" | grep -E '^(find_item|load|format)_g|^rest_(route|attempt|fail|fail_auth|fail_param|cors|bearer|timed|int_of|param_int|path_int|decoded|insert_field)_g' || true)
if [ -n "$kept" ] || ! echo "$fns" | grep -qx handle_g; then
    echo "inline_route: expected these inlined into handle_g:" $kept
    exit 1
fi

echo
echo "test.sh: all passed"
