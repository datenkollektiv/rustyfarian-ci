#!/usr/bin/env bash
set -euo pipefail
# release.sh — tag origin/main as vX.Y.Z and move its major tag (vX), after one confirmation
# Usage: scripts/release.sh <X.Y.Z | vX.Y.Z>
# Callers pin the moving major tag (@v1); every release also gets an immutable vX.Y.Z tag.

input="${1:?usage: scripts/release.sh <X.Y.Z>}"
version="${input#v}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "release: version must be X.Y.Z (got '$input')" >&2
    exit 2
fi
tag="v$version"
major="v${version%%.*}"

if [ "$(git branch --show-current)" != main ]; then
    echo "release: check out main first" >&2
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "release: working tree is not clean" >&2
    exit 1
fi

# --force: the moving major tag differs from the local copy after every release.
git fetch --quiet --tags --force origin
head="$(git rev-parse HEAD)"
if [ "$head" != "$(git rev-parse origin/main)" ]; then
    echo "release: local main is not origin/main; push or pull first" >&2
    exit 1
fi
if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
    echo "release: $tag already exists; release tags are immutable, pick the next version" >&2
    exit 1
fi

previous="$(git rev-parse --quiet --verify "refs/tags/$major^{commit}" || echo none)"
echo "Tag $tag at $(git log -1 --format='%h %s' HEAD)"
echo "Move $major: ${previous:0:7} -> ${head:0:7}"
read -r -p "Push both tags to origin? [y/N] " answer
if ! [[ "$answer" =~ ^[yY]$ ]]; then
    echo "release: aborted, nothing tagged"
    exit 1
fi

git tag -a "$tag" -m "$tag"
git tag -f -a "$major" -m "$major -> $tag"
git push origin "refs/tags/$tag"
git push --force origin "refs/tags/$major"
