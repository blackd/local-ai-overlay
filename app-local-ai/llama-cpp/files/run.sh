#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# A lib/ subdirectory is only present if the package ever ships shared
# libraries; harmless otherwise.
LD_LIBRARY_PATH="${CURDIR}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export LD_LIBRARY_PATH
exec "${CURDIR}/grpc-server" "$@"
