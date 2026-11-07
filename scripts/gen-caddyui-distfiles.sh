#!/bin/bash
# Generates the offline-build tarball for www-apps/caddyui:
# - caddyui-<version>-deps.tar.xz: the Go module cache from go.sum
# Upload the result as an asset of a release tagged caddyui-v<version> on
# this repository.

set -euo pipefail

VERSION="${1:?usage: gen-caddyui-distfiles.sh <version>}"
WORK=$(mktemp -d /tmp/caddyui-distfiles.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

HERE=$(dirname "$(realpath "$0")")

cd "$WORK"
curl -fsSL "https://github.com/X4Applegate/caddyui/archive/refs/tags/v${VERSION}.tar.gz" | tar -xz
bash "${HERE}/gen-go-deps.sh" "$WORK/caddyui-${VERSION}" "$WORK" "$OUT/caddyui-${VERSION}-deps.tar.xz"

echo "Created in $OUT:"
ls -lh "$OUT/caddyui-${VERSION}"-*
