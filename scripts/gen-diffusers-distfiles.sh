#!/bin/bash
# Wheels for the venv layer of app-local-ai/diffusers. Everything
# compiled (torch, tokenizers, safetensors, sentencepiece, opencv, av,
# grpcio…) comes from system packages instead and is EXCLUDED here —
# hence --no-deps with a curated list, not resolver output. The shared
# helpers and gRPC stubs live in app-local-ai/python-common.
# Upload the result as an asset of a release tagged diffusers-v<version>
# on this repository.

set -euo pipefail

VERSION="${1:?usage: gen-diffusers-distfiles.sh <version>}"
HERE=$(dirname "$(realpath "$0")")

# Pins mirror backend/python/diffusers/requirements-hipblas.txt at the
# LocalAI release; unpinned entries ride their latest at generation time.
PACKAGES=(
	diffusers==0.38.0
	transformers==4.57.6
	accelerate
	peft
	huggingface-hub==0.36.2
	optimum-quanto
)

bash "${HERE}/gen-wheels.sh" diffusers "${VERSION}" "${PACKAGES[@]}"
