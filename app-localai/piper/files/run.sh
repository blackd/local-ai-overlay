#!/bin/sh
CURDIR=$(dirname "$(readlink -f "$0")")
ESPEAK_NG_DATA="${CURDIR}/espeak-ng-data"
export ESPEAK_NG_DATA
LD_LIBRARY_PATH="${CURDIR}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export LD_LIBRARY_PATH
exec "${CURDIR}/piper" "$@"
