#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# The Go binary dlopens the compute library named by RFDETR_LIBRARY
# (upstream ships several CPU variants and picks one here; this package
# builds exactly one).
RFDETR_LIBRARY="${CURDIR}/librfdetrcpp.so"
export RFDETR_LIBRARY
exec "${CURDIR}/rfdetr-cpp" "$@"
