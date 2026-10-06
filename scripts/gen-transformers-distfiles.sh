#!/bin/bash
# Wheels for the venv layer of localai-backend/transformers. Parity
# rule: the venv ships everything upstream's install resolves, MINUS
# tree packages — leaving sentence-transformers and diffusers (0.40.0:
# the tree's huggingface-hub 1.26 satisfies its >=1.23 floor; 0.41
# wants >=1.32). torch, transformers, accelerate, bitsandbytes, scipy,
# scikit-learn, pillow, soundfile and the huggingface stack all reach
# the venv via --system-site-packages. llvmlite/numba and the
# Intel/OpenVINO extras are deliberately omitted — see the ebuild.
# Everything is BUILT from PyPI sdists (nobin:), never taken prebuilt.
# Upload as an asset of a release tagged transformers-v<version>.

set -euo pipefail

VERSION="${1:?usage: gen-transformers-distfiles.sh <version>}"

PACKAGES=(
	"nobin:sentence-transformers==6.1.0"
	"nobin:diffusers==0.40.0"
)

bash "$(dirname "$(realpath "$0")")/gen-wheels.sh" transformers "${VERSION}" "${PACKAGES[@]}"
