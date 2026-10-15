#!/bin/sh
# Moves raw benchmark output between machines on the bench-raw branch, which
# shares no history with main. main tracks only what docs cite from a result
# directory (bench/README.md, "Results"); .gitignore keeps the rest out.
#
#   bench/raw.sh push DIR...   commit result directories to bench-raw and push
#   bench/raw.sh pull          list the directories on bench-raw
#   bench/raw.sh pull DIR...   extract them into bench/results/
#
# A DIR is a path or a name under bench/results/. push builds the commit in a
# temporary index, so the checked-out branch and its index stay untouched, and
# a pushed directory replaces its earlier copy on bench-raw.
#
# Settings, from the environment:
#   REMOTE        origin
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
remote=${REMOTE:-origin}
branch=bench-raw

usage() {
    echo "usage: bench/raw.sh push DIR... | pull [DIR...]" >&2
    exit 2
}

[ $# -gt 0 ] || usage
mode=$1
shift
case $mode in
push)
    [ $# -gt 0 ] || usage
    if git ls-remote --exit-code --heads "$remote" "$branch" >/dev/null; then
        git fetch -q "$remote" "$branch"
        parent=$(git rev-parse FETCH_HEAD)
    else
        parent=
    fi
    GIT_INDEX_FILE=$(mktemp)
    export GIT_INDEX_FILE
    trap 'rm -f "$GIT_INDEX_FILE"' EXIT
    if [ -n "$parent" ]; then git read-tree "$parent"; else git read-tree --empty; fi
    names=
    for d; do
        rel=bench/results/$(basename "$d")
        [ -d "$rel" ] || { echo "no directory $rel" >&2; exit 1; }
        git rm -r -q --cached --ignore-unmatch -- "$rel"
        git add -f -- "$rel"
        names="$names $(basename "$d")"
    done
    tree=$(git write-tree)
    if [ -n "$parent" ] && [ "$tree" = "$(git rev-parse "$parent^{tree}")" ]; then
        echo "bench-raw already holds:$names"
        exit 0
    fi
    commit=$(git commit-tree "$tree" ${parent:+-p "$parent"} -m "Add raw benchmark output:$names")
    git push -q "$remote" "$commit:refs/heads/$branch"
    echo "pushed to $remote/$branch:$names"
    ;;
pull)
    git fetch -q "$remote" "$branch"
    if [ $# -eq 0 ]; then
        git ls-tree --name-only FETCH_HEAD bench/results/ | sed 's|^bench/results/||'
        exit 0
    fi
    for d; do
        rel=bench/results/$(basename "$d")
        git archive FETCH_HEAD "$rel" | tar -x -f - -C "$root"
        echo "$rel"
    done
    ;;
*) usage ;;
esac
