#!/bin/bash
# Shared helper for the Go packages: populate a go-module.eclass
# -compatible module cache (go-mod/ under <cache-parent>) from
# <module-dir>'s go.mod with the host go only, and pack the cache as
# <out-tarball>. The go-mod/ directory name is mandated by
# go-module.eclass: it points GOMODCACHE at ${WORKDIR}/go-mod, so a
# tarball with this root works with the eclass's default src_unpack.
set -euo pipefail

MODDIR="${1:?usage: gen-go-deps.sh <module-dir> <cache-parent> <out-tarball>}"
PARENT="${2:?usage: gen-go-deps.sh <module-dir> <cache-parent> <out-tarball>}"
OUTFILE="${3:?usage: gen-go-deps.sh <module-dir> <cache-parent> <out-tarball>}"

# Always the host go. GOTOOLCHAIN=auto would download the release a
# go.mod `toolchain` line names even when the host satisfies the `go`
# directive, and a host that is too old must fail the run so the
# runner image gets bumped, not fetch a compiler from the network.
export GOTOOLCHAIN=local

( cd "$MODDIR" && GOMODCACHE="$PARENT/go-mod" go mod download -modcacherw )
chmod -R u+w "$PARENT/go-mod"
XZ_OPT='-T0 -9' tar -C "$PARENT" -acf "$OUTFILE" go-mod
