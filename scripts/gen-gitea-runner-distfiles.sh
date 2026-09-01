#!/bin/bash
# Generates the Go module cache tarball for dev-util/gitea-runner, in the
# layout go-module.eclass unpacks automatically (go-mod/ at the top level).
# Upload the result as an asset of a release tagged gitea-runner-<version>
# on this repository.

set -euo pipefail

VERSION="${1:?usage: gen-gitea-runner-distfiles.sh <version>}"
WORK=$(mktemp -d /tmp/gitea-runner-distfiles.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

# The module requires go >= 1.27; when the host go is older, let it
# fetch the required toolchain (stripped from the tarball below).
export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"

cd "$WORK"
curl -fsSL "https://gitea.com/gitea/runner/archive/v${VERSION}.tar.gz" | tar -xz
cd runner

GOMODCACHE="$WORK/go-mod" go mod download -modcacherw

# When the host Go is older than the module requires, GOTOOLCHAIN=auto
# downloads a newer toolchain into the module cache; it is not a
# dependency and must not ship in the tarball. Its files also arrive
# read-only, which would break the cleanup trap.
chmod -R u+w "$WORK/go-mod"
rm -rf "$WORK"/go-mod/golang.org/toolchain@* "$WORK"/go-mod/cache/download/golang.org/toolchain

tar -C "$WORK" -cJf "$OUT/gitea-runner-${VERSION}-deps.tar.xz" go-mod

echo "Created:"
ls -lh "$OUT/gitea-runner-${VERSION}-deps.tar.xz"
