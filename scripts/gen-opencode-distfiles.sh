#!/bin/bash
# Generates the offline-build tarballs for dev-util/opencode:
# - opencode-<version>-node_modules.tar.xz: every node_modules directory of
#   the Bun workspace, populated from the pinned bun.lock
# - opencode-<version>-models.json.xz, 1.x only: the models.dev catalog
#   snapshot the 1.x build embeds into the binary (fetched at build time
#   otherwise). 2.x commits its snapshot in packages/core.
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

# Gitea Actions exports GITHUB_API_URL/GITHUB_SERVER_URL pointing at the
# Gitea instance; bun resolves github: dependencies through them, so pin
# the real GitHub endpoints regardless of environment.
export GITHUB_API_URL="https://api.github.com"
export GITHUB_SERVER_URL="https://github.com"

# --ignore-scripts: the workspace trusts electron's postinstall, which
# downloads the Electron binary; nothing the CLI build needs comes from a
# postinstall (esbuild's and the pty's binaries are package files).
bun install --frozen-lockfile --ignore-scripts

find . -name node_modules -type d -prune | sed 's|^\./||' > "$WORK/nm.list"
tar -cJf "$OUT/opencode-${VERSION}-node_modules.tar.xz" -T "$WORK/nm.list"

case "${VERSION}" in
	1.*)
		curl -fsSL https://models.dev/api.json -o "opencode-${VERSION}-models.json"
		xz -c "opencode-${VERSION}-models.json" > "$OUT/opencode-${VERSION}-models.json.xz"
		;;
esac

echo "Created in $OUT:"
ls -lh "$OUT/opencode-${VERSION}"-*
