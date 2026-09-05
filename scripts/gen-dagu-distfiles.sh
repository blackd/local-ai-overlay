#!/bin/bash
# Generates the offline-build tarballs for sys-process/dagu:
# - dagu-<version>-deps.tar.xz: the Go module cache from go.sum
# - dagu-<version>-ui-node_modules.tar.xz: pnpm dependencies of the web UI
# Upload the results as assets of a release tagged dagu-v<version> on this
# repository.

set -euo pipefail

VERSION="${1:?usage: gen-dagu-distfiles.sh <version>}"
WORK=$(mktemp -d /tmp/dagu-distfiles.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

# The module may require a newer go than the host has; when it does, let
# go fetch the required toolchain (stripped from the tarball below).
export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"

cd "$WORK"
curl -fsSL "https://github.com/dagucloud/dagu/archive/refs/tags/v${VERSION}.tar.gz" | tar -xz
cd "dagu-${VERSION}"

GOMODCACHE="$WORK/go-mod" go mod download -modcacherw
chmod -R u+w "$WORK/go-mod"
rm -rf "$WORK"/go-mod/golang.org/toolchain@* "$WORK"/go-mod/cache/download/golang.org/toolchain
tar -C "$WORK" -cJf "$OUT/dagu-${VERSION}-deps.tar.xz" go-mod

# The UI pins its package manager in package.json; npx runs that exact
# pnpm without a global install. pnpm's node_modules is a farm of
# relative symlinks into node_modules/.pnpm and tars fine. The tarball
# carries the source-tree prefix so it unpacks straight into place.
cd ui
PNPM=$(sed -n 's/.*"packageManager": "\(pnpm@[0-9.]*\).*/\1/p' package.json)
npx -y "${PNPM}" install --frozen-lockfile
cd "$WORK"
tar -cJf "$OUT/dagu-${VERSION}-ui-node_modules.tar.xz" "dagu-${VERSION}/ui/node_modules"

echo "Created in $OUT:"
ls -lh "$OUT/dagu-${VERSION}"-*
