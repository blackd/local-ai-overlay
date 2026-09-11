#!/bin/bash
# hf-xet's pypi sdist is an INCOMPLETE cargo workspace (its root
# Cargo.toml references members like git_xet that the sdist omits), so
# both this script and the ebuild source the xet-core repository tag
# instead. hf_xet is EXCLUDED from the repo's root workspace and
# carries its own Cargo.lock — vendor from its directory, not the root.
set -euo pipefail

VERSION="${1:?usage: gen-hf-xet-distfiles.sh <version>}"
WORK=$(mktemp -d /tmp/hf-xet-crates.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
curl -fsSL "https://github.com/huggingface/xet-core/archive/refs/tags/v${VERSION}.tar.gz" | tar -xz
cd "xet-core-${VERSION}/hf_xet"
cargo vendor --locked "$WORK/vendor"
tar -C "$WORK" -cJf "$OUT/hf-xet-${VERSION}-crates.tar.xz" vendor

echo "Created in $OUT:"
ls -lh "$OUT/hf-xet-${VERSION}-crates.tar.xz"
