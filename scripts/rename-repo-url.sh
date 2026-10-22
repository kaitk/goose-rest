#!/bin/sh
# Moves every reference to the GitHub repository kaitk/goose-rest to
# kaitk/plod, once GitHub has renamed it (docs/decisions.md, "The name"):
# imports (github.com/kaitk/goose-rest@<ref>), links, and Goose's cache path.
# History keeps the old name: CHANGELOG.md, docs/decisions.md, tasks/, and
# bench/results/. No doc tells a reader to clone into a directory named
# goose-rest, so no checkout's directory is renamed.
#
#   scripts/rename-repo-url.sh --dry-run   lists each file and line it would change
#   scripts/rename-repo-url.sh             changes them
set -eu
export LC_ALL=C

root=$(cd "$(dirname "$0")/.." && pwd)
case ${1:-} in
--dry-run) dry=1 ;;
"") dry= ;;
*) echo "usage: scripts/rename-repo-url.sh [--dry-run]" >&2; exit 2 ;;
esac

cd "$root"
keep=":!CHANGELOG.md :!docs/decisions.md :!tasks :!bench/results :!scripts/rename-repo-url.sh"
pattern='kaitk/goose-rest([^A-Za-z0-9_-]|$)'
if [ -n "$dry" ]; then
    git grep -n -E "$pattern" -- . $keep || echo "rename-repo-url.sh: nothing to change"
    exit 0
fi
# perl rewrites only the name's bytes, so each file keeps its line endings.
git grep -l -E "$pattern" -- . $keep | while read -r f; do
    perl -pi -e 's{kaitk/goose-rest(?![A-Za-z0-9_-])}{kaitk/plod}g' "$f"
done

left=$(git grep -l -E "$pattern" -- . $keep || true)
[ -z "$left" ] || { echo "rename-repo-url.sh: kaitk/goose-rest is left in: $left" >&2; exit 1; }
echo "kaitk/goose-rest -> kaitk/plod in $(git diff --name-only | wc -l | tr -d ' ') files"
echo "then: git remote set-url origin git@github.com:kaitk/plod.git"
