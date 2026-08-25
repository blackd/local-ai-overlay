#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# The Go binary dlopens the compute library named by SD_LIBRARY (upstream
# ships several CPU variants and picks one here; this package builds
# exactly one).
SD_LIBRARY="${CURDIR}/libgosd.so"
export SD_LIBRARY
exec "${CURDIR}/stablediffusion-ggml" "$@"
