#!/bin/bash
# Generates the offline-build tarballs for dev-util/opencode:
# - opencode-<version>-node_modules.tar.xz: every node_modules directory of
#   the Bun workspace, populated from the pinned bun.lock
# - opencode-<version>-models.json.xz: the models.dev catalog snapshot that
#   the build embeds into the binary (fetched at build time otherwise)
# Run on a machine with network access, dev-lang/bun-bin and xz; upload the
# results as assets of a release tagged opencode-v<version> on this
# repository.

set -euo pipefail

VERSION="${1:?usage: gen-opencode-distfiles.sh <version>}"
WORK=$(mktemp -d /tmp/opencode-distfiles.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
curl -fsSL "https://github.com/anomalyco/opencode/archive/refs/tags/v${VERSION}.tar.gz" | tar -xz
cd "opencode-${VERSION}"

bun install --frozen-lockfile

find . -name node_modules -type d -prune | sed 's|^\./||' > "$WORK/nm.list"
tar -cJf "$OUT/opencode-${VERSION}-node_modules.tar.xz" -T "$WORK/nm.list"

curl -fsSL https://models.dev/api.json -o "opencode-${VERSION}-models.json"
xz -c "opencode-${VERSION}-models.json" > "$OUT/opencode-${VERSION}-models.json.xz"

echo "Created in $OUT:"
ls -lh "$OUT/opencode-${VERSION}"-*
