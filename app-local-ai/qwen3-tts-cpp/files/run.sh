#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# The Go binary dlopens the compute library named by QWEN3TTS_LIBRARY
# (upstream ships several CPU variants and picks one here; this package
# builds exactly one).
QWEN3TTS_LIBRARY="${CURDIR}/libgoqwen3ttscpp.so"
export QWEN3TTS_LIBRARY
exec "${CURDIR}/qwen3-tts-cpp" "$@"
