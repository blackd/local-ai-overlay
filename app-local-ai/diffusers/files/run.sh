#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# Shared helpers and gRPC stubs from app-local-ai/python-common.
PYTHONPATH="/usr/libexec/local-ai/python-common${PYTHONPATH:+:${PYTHONPATH}}"
export PYTHONPATH
exec "${CURDIR}/venv/bin/python" "${CURDIR}/backend.py" "$@"
