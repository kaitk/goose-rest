#!/bin/sh
# Moves the goose-http pin: replaces the full hash rest.goose imports with
# HASH in every tracked file that has it, and the short hash in README.md's
# Pins row. The spikes' READMEs name the commit their output was checked on;
# update those by hand once scripts/test.sh passes (docs/development.md,
# "Move the goose-http pin").
#
#   scripts/move-http-pin.sh HASH   (a full 40-hex commit of goose-http's main)
set -eu
export LC_ALL=C

root=$(cd "$(dirname "$0")/.." && pwd)
new=${1:-}
printf '%s' "$new" | grep -Eq '^[0-9a-f]{40}$' ||
    { echo "usage: scripts/move-http-pin.sh <40-hex commit>" >&2; exit 2; }
old=$(sed -n 's|.*import http from "github.com/kaitk/goose-http@\([0-9a-f]\{40\}\)";.*|\1|p' "$root/rest.goose" | head -1)
[ -n "$old" ] || { echo "move-http-pin.sh: no goose-http import in rest.goose" >&2; exit 1; }
[ "$old" != "$new" ] || { echo "goose-http is already pinned at $new"; exit 0; }

cd "$root"
# perl rewrites only the hash's bytes, so each file keeps its line endings.
git grep -l "$old" | while read -r f; do perl -pi -e "s/$old/$new/g" "$f"; done
perl -pi -e "s/(\`kaitk\/goose-http\` \`)$(printf %.7s "$old")\`/\${1}$(printf %.7s "$new")\`/" README.md

left=$(git grep -l "$old" || true)
[ -z "$left" ] || { echo "move-http-pin.sh: $old is left in: $left" >&2; exit 1; }
echo "goose-http: $(printf %.7s "$old") -> $(printf %.7s "$new") in $(git diff --name-only | wc -l | tr -d ' ') files"
