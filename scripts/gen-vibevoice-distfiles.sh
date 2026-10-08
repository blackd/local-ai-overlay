#!/bin/bash
# Wheels for the venv layer of localai-backend/vibevoice. Parity rule:
# the venv ships what upstream's install resolves MINUS tree packages
# and MINUS the demo/vllm-plugin-only rows (see the ebuild header) —
# leaving transformers (4.57.6, the last 4.x release: the MS package
# pins <5 and its class names collide with the native VibeVoice port
# in transformers >=5.17 — the venv copy shadows the system one),
# librosa (closure is tree packages) and diffusers (0.40.0: the
# tree's huggingface-hub satisfies its floor; 0.41 wants >=1.32).
# Everything is BUILT from PyPI sdists (nobin:), never taken prebuilt.
# Upload as an asset of a release tagged vibevoice-v<version>.

set -euo pipefail

VERSION="${1:?usage: gen-vibevoice-distfiles.sh <version>}"

PACKAGES=(
	"nobin:transformers==4.57.6"
	"nobin:librosa==1.0.0"
	"nobin:diffusers==0.40.0"
)

bash "$(dirname "$(realpath "$0")")/gen-wheels.sh" vibevoice "${VERSION}" "${PACKAGES[@]}"
