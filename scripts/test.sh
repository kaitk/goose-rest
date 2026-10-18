#!/bin/sh
# Runs every test this repository has, and fails on the first step that
# fails: the tests under test/<area>/ (test/run_tests.py, which reports every
# failure among them), the generator's output for each schema under
# test/gen/, examples/, and docs/tutorial/ against its golden file, the
# TypeScript helper's tests where tsc is installed (ts/), each example and
# each tutorial and best-practices program served and requested
# (scripts/test-examples.sh), each tutorial and best-practices test.goose,
# the tests of docs/best-practices/testing/ by its own test/run_tests.py,
# the code blocks of the tutorial's and the best practices' pages against the
# programs they quote, then each spike, whose output must match the
# expected.txt beside it, the output its README records; a spike that spawns
# a thread is built with goose build first. Spike 04's -O2 C must
# also keep main as its only Goose function: everything else inlined. And
# test/inline_route.goose's -O2 C must keep none of its middleware,
# rest::route, or the functions that fail, all inlined into the handler: only
# the handler and library leaves stay functions.
#
# GOOSE names the compiler (default: the pinned release, scripts/goose.sh),
# and TSC the TypeScript compiler's command (default: tsc on PATH, or else
# the TypeScript release below, which npx or bunx fetches, such as
# "npx -y -p typescript@7.0.2 tsc"). JS names the runtime that runs the helper
# (default: node, or else bun), and PYTHON the one that runs
# test/run_tests.py (default: python3, or else python).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/scripts/goose.sh"
goose=$GOOSE
# The TypeScript release the helper's tests last passed with, which npx or
# bunx fetches where no tsc is on PATH.
typescript=typescript@7.0.2
if [ -z "${TSC:-}" ]; then
    if command -v tsc >/dev/null 2>&1; then TSC=tsc
    elif command -v npx >/dev/null 2>&1; then TSC="npx -y -p $typescript tsc"
    elif command -v bunx >/dev/null 2>&1; then TSC="bunx -p $typescript tsc"
    else TSC=
    fi
fi
JS=${JS:-$(command -v node || command -v bun || echo node)}
PYTHON=${PYTHON:-$(command -v python3 || command -v python || echo python3)}

step() {
    echo
    echo "== $*"
}

step "test/run_tests.py"
"$PYTHON" "$root/test/run_tests.py"

# Golden files: what the generator writes from each schema must match the
# committed source byte for byte. test/generated/ compiles one and
# round-trips JSON through it.
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

# The TypeScript helper, only where TSC runs: offline, npx and bunx can't
# fetch it, and the step is skipped. tsc checks ts/, where
# ts/test/reject.mts holds what tsc must refuse. Then JS runs the documents
# written with the helper, each of which must be the JSON it copies and pass
# the generator, and ts/test/generator.mts's, each of which the generator must
# refuse with the error it names.
ts=$root/build/ts
if [ -n "$TSC" ] && $TSC --version >/dev/null 2>&1; then
    step "tsc ts/ ($($TSC --version))"
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
    # The path as the generator prints it: on Windows, Git Bash hands a native
    # program C:/..., not /c/....
    ts_shown=$ts
    if command -v cygpath >/dev/null 2>&1; then ts_shown=$(cygpath -m "$ts"); fi
    while IFS=$tab read -r want doc; do
        printf '%s\n' "$doc" >"$ts/api.json"
        if "$goose" "$root/gen/main.goose" -- gen "$ts/api.json" -o "$ts/api_gen.goose" 2>"$ts/err"; then
            echo "accepted, but want: $want"
            exit 1
        fi
        # The error, without the section of docs/generator.md it ends with,
        # which test/generator/sections.goose checks.
        if ! sed 's/ (generator\.md [^)]*)$//' "$ts/err" | grep -qxF "goose-rest: $ts_shown/api.json: $want"; then
            echo "want: $want"
            grep '^goose-rest' "$ts/err"
            exit 1
        fi
    done <"$ts/cases"
    echo "$(wc -l <"$ts/cases" | tr -d ' ') refused"
else
    step "ts/"
    echo "skipped: no tsc on PATH, and no npx or bunx to fetch $typescript, or the fetch"
    echo "failed; install Node or Bun, or set TSC to a TypeScript compiler's command"
fi

# A program of the docs is a folder under docs/tutorial/ or
# docs/best-practices/ with a requests.sh, one level down or two, for a page
# with several programs. A requests.sh under a program's test/ is one of its
# scenarios, which its own test/run_tests.py runs.
programs=$(find "$root/docs/tutorial" "$root/docs/best-practices" -name requests.sh ! -path '*/test/*' -exec dirname {} \; | sort)
step "test-examples.sh"
# shellcheck disable=SC2086
"$root/scripts/test-examples.sh" "$root"/examples/*/ $programs

for t in $(find "$root/docs/tutorial" "$root/docs/best-practices" -name test.goose | sort); do
    step "${t#"$root"/}"
    "$goose" "$t"
done

# An application's tests, run as the application runs them.
step "docs/best-practices/testing/test/run_tests.py"
GOOSE=$goose "$PYTHON" "$root/docs/best-practices/testing/test/run_tests.py"

# The rust and json blocks of the tutorial's and the best practices' pages
# quote the programs beside them and the examples: each run of lines between
# "..." lines must appear as it is in one of their files. A block's file is
# named <section>.<page>.<block>.<part>.
for section in tutorial best-practices; do
    step "docs/$section/'s code"
    blocks=$root/build/$section-blocks
    rm -rf "$blocks"
    mkdir -p "$blocks"
    awk -v dir="$blocks" -v section="$section" '
        FNR == 1 { page = FILENAME; sub(/.*\//, "", page); sub(/\.md$/, "", page); page = section "." page }
        /^```(rust|json)$/ { n++; part = 0; file = dir "/" page "." n "." part; inside = 1; next }
        inside && /^```$/ { inside = 0; next }
        inside && /^ *\.\.\.$/ { part++; file = dir "/" page "." n "." part; next }
        inside { print > file }
    ' "$root/docs/$section"/*.md
    sources=$(find "$root/docs/$section" "$root/examples" -type f ! -name '*.md' ! -name '*.png' | sort)
    for b in "$blocks"/*; do
        want=$(cat "$b")
        found=
        for f in $sources; do
            case $(cat "$f") in *"$want"*) found=1; break ;; esac
        done
        if [ -z "$found" ]; then
            echo "docs/$section/$(basename "$b" | cut -d. -f2).md quotes what no program holds:"
            cat "$b"
            exit 1
        fi
    done
    echo "$(ls "$blocks" | wc -l | tr -d ' ') excerpts found"
done

mkdir -p "$root/build"
# In Git Bash, a program is named in full: a Linux build in the same tree
# leaves an ELF beside the .exe, which the shell would run first.
case $(uname -s) in
MINGW* | MSYS*) exe=.exe ;;
*) exe= ;;
esac
for f in "$root"/spikes/*/main.goose "$root"/spikes/*/*/main.goose; do
    step "spike ${f#"$root"/}"
    # TinyCC can't run threads: a spike that spawns one is built and run.
    if grep -q thread_spawn "$f"; then
        "$goose" build -o "$root/build/spike" "$f"
        "$root/build/spike$exe" >"$root/build/spike.out"
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
