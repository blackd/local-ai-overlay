#!/bin/bash
# Shared helper for the Go packages: populate a go-module.eclass
# -compatible module cache (go-mod/ under <cache-parent>) from
# <module-dir>'s go.mod, strip the Go toolchain that GOTOOLCHAIN=auto
# may have downloaded (it is not a dependency, weighs hundreds of MB,
# and its read-only files break `trap rm -rf` cleanups), and pack the
# cache as <out-tarball>. The go-mod/ directory name is mandated by
# go-module.eclass: it points GOMODCACHE at ${WORKDIR}/go-mod, so a
# tarball with this root works with the eclass's default src_unpack.
set -euo pipefail

MODDIR="${1:?usage: gen-go-deps.sh <module-dir> <cache-parent> <out-tarball>}"
PARENT="${2:?usage: gen-go-deps.sh <module-dir> <cache-parent> <out-tarball>}"
OUTFILE="${3:?usage: gen-go-deps.sh <module-dir> <cache-parent> <out-tarball>}"

# The module may require a newer go than the host has; when it does,
# let go fetch the required toolchain (stripped again below).
export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"

( cd "$MODDIR" && GOMODCACHE="$PARENT/go-mod" go mod download -modcacherw )
chmod -R u+w "$PARENT/go-mod"
rm -rf "$PARENT"/go-mod/golang.org/toolchain@* "$PARENT"/go-mod/cache/download/golang.org/toolchain
XZ_OPT='-T0 -9' tar -C "$PARENT" -acf "$OUTFILE" go-mod
