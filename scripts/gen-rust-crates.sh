#!/bin/bash
# Shared helper for the Rust/maturin python packages: fetch the pypi
# sdist, vendor its locked crate graph, and emit
# <name>-<version>-crates.tar.xz in the caller's working directory.
# Callers (gen-<name>-distfiles.sh) pass: <name> <version> <lockdir>
# where <lockdir> is the sdist-relative directory holding Cargo.lock
# (bindings/python for the HuggingFace workspaces).

set -euo pipefail

NAME="${1:?usage: gen-rust-crates.sh <name> <version> <lockdir>}"
VERSION="${2:?usage: gen-rust-crates.sh <name> <version> <lockdir>}"
LOCKDIR="${3:?usage: gen-rust-crates.sh <name> <version> <lockdir>}"
WORK=$(mktemp -d "/tmp/${NAME}-crates.XXXXXX")
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
curl -fsSL "https://files.pythonhosted.org/packages/source/${NAME:0:1}/${NAME}/${NAME}-${VERSION}.tar.gz" | tar -xz
cd "${NAME}-${VERSION}/${LOCKDIR}"
cargo vendor --locked "$WORK/vendor"
tar -C "$WORK" -cJf "$OUT/${NAME}-${VERSION}-crates.tar.xz" vendor

echo "Created in $OUT:"
ls -lh "$OUT/${NAME}-${VERSION}-crates.tar.xz"
