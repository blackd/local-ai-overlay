#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
exec "${CURDIR}/venv/bin/python" "${CURDIR}/backend.py" "$@"
