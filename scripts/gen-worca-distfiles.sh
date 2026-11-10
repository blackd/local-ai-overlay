#!/bin/bash
# Generates the offline-install tarball for dev-util/worca:
# - worca-<version>-node_modules.tar.xz: the production dependencies of
#   @worca/app, resolved from the npm-shrinkwrap.json the npm tarball
#   ships. Install scripts are not run: node-pty is compiled by the
#   ebuild, ffmpeg-static only downloads a binary and is removed.
# Run on a machine with network access, net-libs/nodejs[npm] and xz;
# upload the result as an asset of a release tagged worca-v<version> on
# this repository.
set -euo pipefail

VERSION="${1:?usage: gen-worca-distfiles.sh <version>}"
WORK=$(mktemp -d /tmp/worca-distfiles.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
curl -fsSL "https://registry.npmjs.org/@worca/app/-/app-${VERSION}.tgz" | tar -xz
cd package
npm ci --omit=dev --ignore-scripts --no-audit --no-fund
rm -rf node_modules/ffmpeg-static
tar -cJf "$OUT/worca-${VERSION}-node_modules.tar.xz" node_modules

echo "Created in $OUT:"
ls -lh "$OUT/worca-${VERSION}"-*
