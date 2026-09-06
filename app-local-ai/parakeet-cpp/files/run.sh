#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# The Go binary dlopens the compute library named by PARAKEET_LIBRARY
# (upstream stages the engine build next to the binary; this package
# installs exactly one library).
PARAKEET_LIBRARY="${CURDIR}/libparakeet.so"
export PARAKEET_LIBRARY
exec "${CURDIR}/parakeet-cpp" "$@"
