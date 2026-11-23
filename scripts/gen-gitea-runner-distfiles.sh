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

HERE=$(dirname "$(realpath "$0")")

cd "$WORK"
# gitea.com's archive endpoint answered 403 until the web UI was
# visited (2026-11-23); fetch the releases page first to appease
# whatever anti-automation check sits in front. If it recurs, the next
# step is a browser-like User-Agent on these requests.
curl -fsSL -o /dev/null https://gitea.com/gitea/runner/releases
# The source tarball becomes a release asset too: gitea.com's 403
# filter and its regenerated-on-demand archives otherwise hit every
# user's emerge fetch directly.
curl -fsSL -o "$OUT/gitea-runner-${VERSION}.tar.gz" "https://gitea.com/gitea/runner/archive/v${VERSION}.tar.gz"
tar -xzf "$OUT/gitea-runner-${VERSION}.tar.gz"
cd runner

bash "${HERE}/gen-go-deps.sh" "$WORK/runner" "$WORK" "$OUT/gitea-runner-${VERSION}-deps.tar.xz"

echo "Created:"
ls -lh "$OUT/gitea-runner-${VERSION}-deps.tar.xz" "$OUT/gitea-runner-${VERSION}.tar.gz"
