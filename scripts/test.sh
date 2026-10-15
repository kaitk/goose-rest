#!/bin/sh
# Runs every test this repository has, and fails on the first failure: the
# typecheck of each root file under test/, the unit tests through TinyCC
# (scripts/test-unit.sh), the generator's output for each schema under
# test/gen/, examples/, and docs/tutorial/ against its golden file, the
# TypeScript helper's tests where tsc is installed (ts/), each example and
# tutorial program served and requested (scripts/test-examples.sh), each
# tutorial test.goose, the tutorial pages' code blocks against the programs
# they quote, then each spike, whose output must match the
# expected.txt beside it, the output its README records; a spike that spawns
# a thread is built with goose build first. Spike 04's -O2 C must
# also keep main as its only Goose function: everything else inlined. And
# test/inline_route.goose's -O2 C must keep none of its middleware,
# rest::route, or the functions that fail, all inlined into the handler: only
# the handler and library leaves stay functions.
#
# GOOSE names the compiler (default: the pinned release, scripts/goose.sh),
# and TSC the TypeScript compiler's command (default: tsc on PATH), such as
# "npx -p typescript tsc". JS names the runtime that runs the helper
# (default: node, or else bun).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/scripts/goose.sh"
goose=$GOOSE
TSC=${TSC:-tsc}
JS=${JS:-$(command -v node || command -v bun || echo node)}

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
for f in "$root"/test/gen/*.json "$root"/examples/*/api.json \
         $(find "$root/docs/tutorial" -name api.json | sort) \
         "$root"/bench/rest/goose-rest/github.json; do
    name=$(basename "$f" .json)
    dir=$(dirname "$f")
    step "gen ${f#"$root"/}"
    "$goose" "$root/gen/main.goose" -- gen "$f" -o "$root/build/gen/${name}_gen.goose"
    diff -u "$dir/${name}_gen.goose" "$root/build/gen/${name}_gen.goose"
done

# The TypeScript helper, only where tsc is: tsc checks ts/, where
# ts/test/reject.mts holds what tsc must refuse. Then JS runs the documents
# written with the helper, each of which must be the JSON it copies and pass
# the generator, and ts/test/generator.mts's, each of which the generator must
# refuse with the error it names.
ts=$root/build/ts
if command -v "${TSC%% *}" >/dev/null 2>&1; then
    step "tsc ts/"
    $TSC -p "$root/ts"
    for pair in ts/test/projects.mts:test/gen/api.json ts/test/schema.mts:examples/schema/api.json \
                ts/test/routes.mts:test/gen/routes.json docs/tutorial/05-schema/api.mts:docs/tutorial/05-schema/api.json; do
        mts=${pair%%:*}
        json=$root/${pair#*:}
        name=$(basename "$(dirname "$mts")")-$(basename "$mts" .mts)
        step "$mts"
        mkdir -p "$ts/$name"
        "$JS" "$root/$mts" >"$ts/$name/api.json"
        "$JS" -e 'const fs = require("fs"), j = (p) => JSON.stringify(JSON.parse(fs.readFileSync(p, "utf8")));
                 if (j(process.argv[1]) !== j(process.argv[2])) { console.log("differs from " + process.argv[2]); process.exit(1); }' \
            "$ts/$name/api.json" "$json"
        "$goose" "$root/gen/main.goose" -- gen "$ts/$name/api.json" -o "$ts/$name/api_gen.goose"
    done
    step "ts/test/generator.mts"
    "$JS" "$root/ts/test/generator.mts" >"$ts/cases"
    tab=$(printf '\t')
    while IFS=$tab read -r want doc; do
        printf '%s\n' "$doc" >"$ts/api.json"
        if "$goose" "$root/gen/main.goose" -- gen "$ts/api.json" -o "$ts/api_gen.goose" 2>"$ts/err"; then
            echo "accepted, but want: $want"
            exit 1
        fi
        if ! grep -qxF "goose-rest: $ts/api.json: $want" "$ts/err"; then
            echo "want: $want"
            grep '^goose-rest' "$ts/err"
            exit 1
        fi
    done <"$ts/cases"
    echo "$(wc -l <"$ts/cases" | tr -d ' ') refused"
else
    step "ts/"
    echo "skipped: no ${TSC%% *} on PATH (TSC names another)"
fi

# A tutorial program is a folder under docs/tutorial/ with a requests.sh, one
# level down or two, for a page with several programs.
tutorial=$(find "$root/docs/tutorial" -name requests.sh -exec dirname {} \; | sort)
step "test-examples.sh"
# shellcheck disable=SC2086
"$root/scripts/test-examples.sh" "$root"/examples/*/ $tutorial

for t in $(find "$root/docs/tutorial" -name test.goose | sort); do
    step "${t#"$root"/}"
    "$goose" "$t"
done

# The tutorial pages' rust and json blocks quote the tutorial's programs and
# the examples: each run of lines between "..." lines must appear as it is
# in one of their files.
step "docs/tutorial/'s code"
blocks=$root/build/tutorial-blocks
rm -rf "$blocks"
mkdir -p "$blocks"
awk -v dir="$blocks" '
    FNR == 1 { page = FILENAME; sub(/.*\//, "", page); sub(/\.md$/, "", page) }
    /^```(rust|json)$/ { n++; part = 0; file = dir "/" page "." n "." part; inside = 1; next }
    inside && /^```$/ { inside = 0; next }
    inside && /^ *\.\.\.$/ { part++; file = dir "/" page "." n "." part; next }
    inside { print > file }
' "$root"/docs/tutorial/*.md
sources=$(find "$root/docs/tutorial" "$root/examples" -type f ! -name '*.md' | sort)
for b in "$blocks"/*; do
    want=$(cat "$b")
    found=
    for f in $sources; do
        case $(cat "$f") in *"$want"*) found=1; break ;; esac
    done
    if [ -z "$found" ]; then
        echo "docs/tutorial/$(basename "$b" | cut -d. -f1).md quotes what no program holds:"
        cat "$b"
        exit 1
    fi
done
echo "$(ls "$blocks" | wc -l | tr -d ' ') excerpts found"

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
kept=$(echo "$fns" | grep -E '^(find_item|load|format|member_routes|signed_in_routes)_g|^rest_(routes|route|attempt|fail|fail_auth|fail_param|cors|bearer|timed|int_of|param_int|path_int|decoded|fill_timing)_g' || true)
if [ -n "$kept" ] || ! echo "$fns" | grep -qx handle_g; then
    echo "inline_route: expected these inlined into handle_g:" $kept
    exit 1
fi

echo
echo "test.sh: all passed"
