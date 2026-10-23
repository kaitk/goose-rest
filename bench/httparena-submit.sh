#!/bin/sh
# Prepares a pull request of Plod's entry to HttpArena (MDA2AV/HttpArena) in
# the HttpArena checkout DIR, cloned if missing, whose origin is the fork the
# pull request comes from. frameworks/plod becomes bench/httparena/plod as
# Plod's HEAD has it, in one commit on branch plod. It pushes nothing.
#
#   HTTPARENA_COMMIT=origin/main bench/httparena.sh validate   # first
#   bench/httparena-submit.sh DIR
#
# While a pull request from branch plod is open, as gh reports it, the commit
# goes on top of the fork's plod: HttpArena's bot commits benchmark results
# there. Push it with git push origin plod. Otherwise branch plod starts from
# HttpArena's main: push it with git push -f origin plod, and open the pull
# request with gh pr create --repo MDA2AV/HttpArena --head <owner>:plod.
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
open=$(gh pr list --repo MDA2AV/HttpArena --head plod --state open --json number --jq length)
if [ "$open" -gt 0 ]; then
    git -C "$dir" fetch -q origin plod
    git -C "$dir" checkout -q plod
    git -C "$dir" merge -q --ff-only FETCH_HEAD
else
    # From the URL, not a remote: once the fork is added, origin is the fork.
    git -C "$dir" fetch -q "$upstream" main
    git -C "$dir" checkout -q -B plod FETCH_HEAD
fi

if [ -d "$dir/frameworks/plod" ]; then
    subject="Update plod to Plod $(git -C "$root" rev-parse --short HEAD)"
else
    subject="Add plod (Goose, standard mode)"
fi
rm -rf "$dir/frameworks/plod"
git -C "$root" archive HEAD "$entry" | tar -x -C "$dir/frameworks" --strip-components 2
git -C "$dir" add -A frameworks/plod
if git -C "$dir" diff --cached --quiet; then
    echo "frameworks/plod already matches Plod's $(git -C "$root" rev-parse --short HEAD)"
    exit 0
fi
git -C "$dir" commit -q -m "$subject"
git -C "$dir" log --oneline -1
git -C "$dir" show --stat --format= HEAD
