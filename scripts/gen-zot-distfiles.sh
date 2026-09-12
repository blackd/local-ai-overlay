#!/bin/bash
# Generates the offline-build tarballs for app-containers/zot:
# - zot-<version>-deps.tar.xz: the Go module cache from go.sum
# - zot-<version>-zui-node_modules.tar.xz: npm dependencies of the zui web
#   interface at the tag zot's Makefile pins (ZUI_VERSION)
# Upload the results as assets of a release tagged zot-v<version> on this
# repository.

set -euo pipefail

VERSION="${1:?usage: gen-zot-distfiles.sh <version>}"
WORK=$(mktemp -d /tmp/zot-distfiles.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

HERE=$(dirname "$(realpath "$0")")

cd "$WORK"
curl -fsSL "https://github.com/project-zot/zot/archive/refs/tags/v${VERSION}.tar.gz" | tar -xz
cd "zot-${VERSION}"

ZUI_PIN=$(sed -n 's/^ZUI_VERSION := //p' Makefile)

bash "${HERE}/gen-go-deps.sh" "$WORK/zot-${VERSION}" "$WORK" "$OUT/zot-${VERSION}-deps.tar.xz"

cd "$WORK"
curl -fsSL "https://github.com/project-zot/zui/archive/refs/tags/${ZUI_PIN}.tar.gz" | tar -xz
cd "zui-${ZUI_PIN}"
npm ci
tar -cJf "$OUT/zot-${VERSION}-zui-node_modules.tar.xz" node_modules

echo "Created in $OUT:"
ls -lh "$OUT/zot-${VERSION}"-*
