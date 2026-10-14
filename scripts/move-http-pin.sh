#!/bin/sh
# Moves the goose-http pin: replaces the reference rest.goose imports with
# REF in every tracked file that has it, and the reference in README.md's
# Pins row, a tag with the commit it resolves to in GOOSE_HTTP's checkout
# (../goose-http). The row's date and the spikes' READMEs, which name the
# commit their output was checked on, are updated by hand once
# scripts/test.sh passes (docs/development.md, "Move the goose-http pin").
#
#   scripts/move-http-pin.sh REF   (a release tag or a full 40-hex commit)
set -eu
export LC_ALL=C

root=$(cd "$(dirname "$0")/.." && pwd)
new=${1:-}
printf '%s' "$new" | grep -Eq '^([0-9a-f]{40}|v[0-9]+\.[0-9]+\.[0-9]+)$' ||
    { echo "usage: scripts/move-http-pin.sh <release tag or 40-hex commit>" >&2; exit 2; }
old=$(sed -n 's|.*import http from "github.com/kaitk/goose-http@\([^"]*\)";.*|\1|p' "$root/rest.goose" | head -1)
[ -n "$old" ] || { echo "move-http-pin.sh: no goose-http import in rest.goose" >&2; exit 1; }
[ "$old" != "$new" ] || { echo "goose-http is already pinned at $new"; exit 0; }
row=$new
if [ "${#new}" -ne 40 ]; then
    gh=${GOOSE_HTTP:-$root/../goose-http}
    commit=$(git -C "$gh" rev-parse --verify -q "$new^{commit}") ||
        { echo "move-http-pin.sh: $new isn't a tag in $gh; fetch its tags" >&2; exit 1; }
    row="$new\`, commit \`$(printf %.7s "$commit")"
else
    row=$(printf %.7s "$new")
fi

cd "$root"
# perl rewrites only the hash's bytes, so each file keeps its line endings.
git grep -l -F "goose-http@$old" | while read -r f; do
    OLD_HTTP_REF=$old NEW_HTTP_REF=$new perl -pi -e \
        's/(goose-http\@)\Q$ENV{OLD_HTTP_REF}\E/$1$ENV{NEW_HTTP_REF}/g' "$f"
done
old_short=$old
[ "${#old}" -ne 40 ] || old_short=$(printf %.7s "$old")
# A tag's row names its commit too, "`v0.3.1`, commit `faead67`": both go.
OLD_HTTP_REF=$old_short NEW_HTTP_ROW=$row perl -pi -e \
    's/(`kaitk\/goose-http` `)\Q$ENV{OLD_HTTP_REF}\E`(, commit `[0-9a-f]+`)?/$1$ENV{NEW_HTTP_ROW}`/' README.md

left=$(git grep -l -F "goose-http@$old" || true)
[ -z "$left" ] || { echo "move-http-pin.sh: $old is left in: $left" >&2; exit 1; }
echo "goose-http: $(printf %.7s "$old") -> $(printf %.7s "$new") in $(git diff --name-only | wc -l | tr -d ' ') files"
