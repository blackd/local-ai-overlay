#!/bin/bash
# Regenerate Manifests for the given package directories; commit and
# push only when something changed. The push retries — sibling release
# jobs race their Manifest commits (that is the normal case, not an
# error). Commit message names the release via RELEASE_TAG when set.
#
# Usage: manifest-and-push.sh <pkg-dir>...
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: manifest-and-push.sh <pkg-dir>..." >&2; exit 1; }
REPO=$(dirname "$(dirname "$(realpath "$0")")")
cd "$REPO"

for d in "$@"; do
	d="${d%/}"
	eb=$(ls "${d}"/*.ebuild | sort -V | tail -n1)
	# FORCE=--force after a (re)release: the fresh assets must replace
	# the recorded digests. Otherwise plain manifest is a cheap no-op
	# on complete Manifests and self-heals incomplete ones.
	ebuild ${FORCE:-} "${eb}" manifest
done

git config user.name "gitea-actions"
git config user.email "gitea-actions@noreply.ipnmod.org"
for d in "$@"; do git add -- "${d%/}/Manifest"; done
if git diff --cached --quiet; then
	echo ">>> manifests unchanged, nothing to commit"
	exit 0
fi
git commit -m "Manifests for ${RELEASE_TAG:-$(basename "$1")}"

for i in 1 2 3 4 5; do
	git pull --rebase origin master && git push origin HEAD:master && exit 0
	[ "$i" = 5 ] && exit 1
	sleep $((i * 5))
done
