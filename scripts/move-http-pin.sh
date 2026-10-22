#!/bin/sh
# Moves the goose-http pin: replaces the reference plod.goose imports with
# REF in every tracked file that has it. The spikes' READMEs, which name the
# commit their output was checked on, are updated by hand once
# scripts/test.sh passes (agents/pins.md, "The goose-http pin"). README.md's
# quick start and tutorial page 01 name the latest release pair, which moves
# with a release, so they're left alone.
#
#   scripts/move-http-pin.sh REF   (a release tag or a full 40-hex commit)
set -eu
export LC_ALL=C

root=$(cd "$(dirname "$0")/.." && pwd)
new=${1:-}
printf '%s' "$new" | grep -Eq '^([0-9a-f]{40}|v[0-9]+\.[0-9]+\.[0-9]+)$' ||
    { echo "usage: scripts/move-http-pin.sh <release tag or 40-hex commit>" >&2; exit 2; }
old=$(sed -n 's|.*import http from "github.com/kaitk/goose-http@\([^"]*\)";.*|\1|p' "$root/plod.goose" | head -1)
[ -n "$old" ] || { echo "move-http-pin.sh: no goose-http import in plod.goose" >&2; exit 1; }
[ "$old" != "$new" ] || { echo "goose-http is already pinned at $new"; exit 0; }

cd "$root"
# perl rewrites only the hash's bytes, so each file keeps its line endings.
pair=":!README.md :!docs/tutorial/01-running.md"
git grep -l -F "goose-http@$old" -- . $pair | while read -r f; do
    OLD_HTTP_REF=$old NEW_HTTP_REF=$new perl -pi -e \
        's/(goose-http\@)\Q$ENV{OLD_HTTP_REF}\E/$1$ENV{NEW_HTTP_REF}/g' "$f"
done

left=$(git grep -l -F "goose-http@$old" -- . $pair || true)
[ -z "$left" ] || { echo "move-http-pin.sh: $old is left in: $left" >&2; exit 1; }
echo "goose-http: $(printf %.7s "$old") -> $(printf %.7s "$new") in $(git diff --name-only | wc -l | tr -d ' ') files"
