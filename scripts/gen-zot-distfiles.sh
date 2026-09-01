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

# The module may require a newer go than the host has; when it does, let
# go fetch the required toolchain (stripped from the tarball below).
export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"

cd "$WORK"
curl -fsSL "https://github.com/project-zot/zot/archive/refs/tags/v${VERSION}.tar.gz" | tar -xz
cd "zot-${VERSION}"

ZUI_PIN=$(sed -n 's/^ZUI_VERSION := //p' Makefile)

GOMODCACHE="$WORK/go-mod" go mod download -modcacherw
chmod -R u+w "$WORK/go-mod"
rm -rf "$WORK"/go-mod/golang.org/toolchain@* "$WORK"/go-mod/cache/download/golang.org/toolchain
tar -C "$WORK" -cJf "$OUT/zot-${VERSION}-deps.tar.xz" go-mod

cd "$WORK"
curl -fsSL "https://github.com/project-zot/zui/archive/refs/tags/${ZUI_PIN}.tar.gz" | tar -xz
cd "zui-${ZUI_PIN}"
npm ci
tar -cJf "$OUT/zot-${VERSION}-zui-node_modules.tar.xz" node_modules

echo "Created in $OUT:"
ls -lh "$OUT/zot-${VERSION}"-*
