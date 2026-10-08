#!/bin/bash
# Wheels for the venv layer of localai-backend/vibevoice. Parity rule:
# the venv ships what upstream's install resolves MINUS tree packages
# and MINUS the demo/vllm-plugin-only rows (see the ebuild header) —
# leaving librosa (closure is tree packages) and diffusers (0.40.0:
# the tree's huggingface-hub satisfies its floor; 0.41 wants >=1.32).
# Everything is BUILT from PyPI sdists (nobin:), never taken prebuilt.
# Upload as an asset of a release tagged vibevoice-v<version>.

set -euo pipefail

VERSION="${1:?usage: gen-vibevoice-distfiles.sh <version>}"

PACKAGES=(
	"nobin:librosa==1.0.0"
	"nobin:diffusers==0.40.0"
)

bash "$(dirname "$(realpath "$0")")/gen-wheels.sh" vibevoice "${VERSION}" "${PACKAGES[@]}"
