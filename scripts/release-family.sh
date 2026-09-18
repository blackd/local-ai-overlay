#!/bin/bash
# Release one distfiles family: check whether <family>-v<version> is
# already released, generate and publish only when it is missing — or
# delete and republish when re-release is requested. Runs inside a
# workflow job (GITHUB_API_URL, GITHUB_REPOSITORY, GITHUB_TOKEN) with
# the repo checkout as CWD; generated tarballs are also copied to
# /var/cache/distfiles for the manifest step that follows.
#
# Usage: release-family.sh <family> <version> [true|false(rerelease)]
set -euo pipefail

FAMILY="${1:?usage: release-family.sh <family> <version> [rerelease]}"
VERSION="${2:?usage: release-family.sh <family> <version> [rerelease]}"
RERELEASE="${3:-false}"

TAG="${FAMILY}-v${VERSION}"
API="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}"
AUTH="Authorization: token ${GITHUB_TOKEN}"
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
	# The tag may already be gone; only the release must not survive.
	curl -s -X DELETE -H "${AUTH}" "${API}/tags/${TAG}" >/dev/null
fi

WORK=$(mktemp -d /tmp/release-family.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
( cd "$WORK" && bash "${HERE}/gen-${FAMILY}-distfiles.sh" "${VERSION}" )

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
