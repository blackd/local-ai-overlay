#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# The Go binary dlopens the compute library named by VIBEVOICECPP_LIBRARY
# (upstream ships several CPU variants and picks one here; this package
# builds exactly one).
VIBEVOICECPP_LIBRARY="${CURDIR}/libgovibevoicecpp.so"
export VIBEVOICECPP_LIBRARY
exec "${CURDIR}/vibevoice-cpp" "$@"
