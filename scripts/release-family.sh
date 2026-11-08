#!/bin/bash
# Release one distfiles family: check whether <family>-v<version> is
# already released, generate and publish only when it is missing — or
# delete and republish when re-release is requested. Runs inside a
# workflow job with the repo checkout as CWD; generated tarballs are
# also copied to /var/cache/distfiles for the manifest step that
# follows.
#
# Releases go to the public instance (RELEASE_API, RELEASE_TOKEN), the
# repository the ebuilds fetch from, not to the one the workflow runs
# in. The release tag is created here and the public repository, a push
# mirror of this one, receives it with a lag, so the release waits for
# the tag before it is created.
#
# Usage: release-family.sh <family> <version> [true|false(rerelease)]
set -euo pipefail

FAMILY="${1:?usage: release-family.sh <family> <version> [rerelease]}"
VERSION="${2:?usage: release-family.sh <family> <version> [rerelease]}"
RERELEASE="${3:-false}"

TAG="${FAMILY}-v${VERSION}"
API="${RELEASE_API:?set RELEASE_API to the API URL of the public repository}"
AUTH="Authorization: token ${RELEASE_TOKEN:?set RELEASE_TOKEN to a token for the public instance}"
# This repository, where the release tag is created and the mirror pushes from.
SRC_API="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}"
SRC_AUTH="Authorization: token ${GITHUB_TOKEN:?GITHUB_TOKEN is needed to tag this repository}"
HERE=$(dirname "$(realpath "$0")")
SHA=$(git rev-parse HEAD)

rid=$(curl -sf -H "${AUTH}" "${API}/releases/tags/${TAG}" | jq -r .id || true)
if [ -n "${rid}" ] && [ "${rid}" != "null" ]; then
	if [ "${RERELEASE}" != "true" ]; then
		echo ">>> ${TAG} already released (id ${rid}), skipping"
		[ -n "${GITHUB_OUTPUT:-}" ] && echo "released=false" >> "$GITHUB_OUTPUT"
		exit 0
	fi
	echo ">>> deleting release ${TAG} (id ${rid}) for re-release"
	curl -sf -X DELETE -H "${AUTH}" "${API}/releases/${rid}"
	# The tag goes here, the mirror removes the public copy. It may
	# already be gone; only the release must not survive.
	curl -s -X DELETE -H "${SRC_AUTH}" "${SRC_API}/tags/${TAG}" >/dev/null
	curl -s -X DELETE -H "${AUTH}" "${API}/tags/${TAG}" >/dev/null
fi

WORK=$(mktemp -d /tmp/release-family.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
( cd "$WORK" && bash "${HERE}/gen-${FAMILY}-distfiles.sh" "${VERSION}" )

# The release tag is created on this repository, the mirror source: a
# tag that exists only on the public side is pruned by the next mirror
# push (git push --mirror), which turns its release into a draft.
echo ">>> tagging ${TAG} at ${SHA}"
curl -sf -X POST -H "${SRC_AUTH}" -H 'Content-Type: application/json' -d "{\"tag_name\":\"${TAG}\",\"target\":\"${SHA}\"}" "${SRC_API}/tags" >/dev/null
for i in $(seq 1 60); do curl -sf -o /dev/null -H "${AUTH}" "${API}/tags/${TAG}" && break; [ "$i" -lt 60 ] || { echo "tag ${TAG} has not reached the public mirror after 5 minutes" >&2; exit 1; }; sleep 5; done

echo ">>> creating release ${TAG} at ${SHA}"
rid=$(curl -sf -X POST -H "${AUTH}" -H 'Content-Type: application/json' \
	-d "{\"tag_name\":\"${TAG}\",\"target_commitish\":\"${SHA}\",\"name\":\"${TAG}\"}" \
	"${API}/releases" | jq -r .id)
[ -n "${rid}" ] && [ "${rid}" != "null" ] || { echo "release creation failed" >&2; exit 1; }

for f in "$WORK"/*; do
	base=$(basename "$f")
	curl -sf -X POST -H "${AUTH}" -F "attachment=@${f}" \
		"${API}/releases/${rid}/assets?name=${base}" >/dev/null
	echo ">>> uploaded ${base}"
done

cp "$WORK"/* /var/cache/distfiles/
[ -n "${GITHUB_OUTPUT:-}" ] && echo "released=true" >> "$GITHUB_OUTPUT"
exit 0
