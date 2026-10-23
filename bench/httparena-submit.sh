#!/bin/sh
# Prepares a pull request of Plod's entry to HttpArena (MDA2AV/HttpArena): in
# the HttpArena checkout DIR, cloned if missing, branch plod starts from
# HttpArena's main, and frameworks/plod becomes bench/httparena/plod as Plod's
# HEAD has it, in one commit. It pushes nothing.
#
#   HTTPARENA_COMMIT=origin/main bench/httparena.sh validate   # first
#   bench/httparena-submit.sh DIR
#
# Then, from DIR: gh repo fork --remote (once), git push -f origin plod, and
# gh pr create --repo MDA2AV/HttpArena.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
dir=${1:?usage: bench/httparena-submit.sh DIR}
upstream=https://github.com/MDA2AV/HttpArena.git
entry=bench/httparena/plod

if [ -n "$(git -C "$root" status --porcelain -- "$entry")" ]; then
    echo "$entry has uncommitted changes; commit them first" >&2
    exit 1
fi
if grep -rn '@[0-9a-f]\{12,\}"' "$root/$entry"; then
    echo "the entry imports a commit, not a release" >&2
    exit 1
fi

if [ ! -d "$dir/.git" ]; then
    git clone -q "$upstream" "$dir"
fi
if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "$dir has uncommitted changes" >&2
    exit 1
fi
# From the URL, not a remote: once the fork is added, origin is the fork.
git -C "$dir" fetch -q "$upstream" main
git -C "$dir" checkout -q -B plod FETCH_HEAD

if [ -d "$dir/frameworks/plod" ]; then
    subject="Update plod to Plod $(grep -o 'plod@v[0-9.]*' "$root/$entry/server.goose" | cut -d@ -f2)"
else
    subject="Add plod (Goose, standard mode)"
fi
rm -rf "$dir/frameworks/plod"
git -C "$root" archive HEAD "$entry" | tar -x -C "$dir/frameworks" --strip-components 2
git -C "$dir" add -A frameworks/plod
git -C "$dir" commit -q -m "$subject"
git -C "$dir" log --oneline -1
git -C "$dir" show --stat --format= HEAD
