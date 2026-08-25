#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# The Go binary dlopens the compute library named by WHISPER_LIBRARY
# (upstream ships several CPU variants and picks one here; this package
# builds exactly one).
WHISPER_LIBRARY="${CURDIR}/libgowhisper.so"
export WHISPER_LIBRARY
exec "${CURDIR}/whisper" "$@"
