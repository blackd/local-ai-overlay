#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# The Go binary dlopens the compute library named by VLLM_CPP_LIBRARY
# (one portable library per platform; SIMD dispatch is at runtime).
VLLM_CPP_LIBRARY="${CURDIR}/libvllm.so"
export VLLM_CPP_LIBRARY
exec "${CURDIR}/vllm-cpp" "$@"
