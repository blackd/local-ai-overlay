#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# The Go binary dlopens the compute library named by DEPTHANYTHING_LIBRARY
# (upstream ships several CPU variants and picks one here; this package
# builds exactly one).
DEPTHANYTHING_LIBRARY="${CURDIR}/libdepthanything.so"
export DEPTHANYTHING_LIBRARY
exec "${CURDIR}/depth-anything" "$@"
