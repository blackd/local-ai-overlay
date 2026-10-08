#!/bin/bash
# Wheels for the venv layer of localai-backend/vibevoice. Parity rule:
# the venv ships what upstream's install resolves MINUS tree packages
# and MINUS the demo/vllm-plugin-only rows (see the ebuild header) —
# leaving transformers (4.57.6, the last 4.x release: the MS package
# pins <5 and its class names collide with the native VibeVoice port
# in transformers >=5.17 — the venv copy shadows the system one),
# huggingface-hub 0.36.2 (transformers 4.x enforces hub <1.0 at
# import; the venv copy shadows the tree's 1.x), librosa (closure is
# tree packages) and diffusers (0.39.0: the last release accepting
# hub <1.0 — 0.40 floors it at 1.23).
# Everything is BUILT from PyPI sdists (nobin:), never taken prebuilt.
# Upload as an asset of a release tagged vibevoice-v<version>.

set -euo pipefail

VERSION="${1:?usage: gen-vibevoice-distfiles.sh <version>}"

PACKAGES=(
	"nobin:transformers==4.57.6"
	"nobin:huggingface-hub==0.36.2"
	"nobin:librosa==1.0.0"
	"nobin:diffusers==0.39.0"
)

bash "$(dirname "$(realpath "$0")")/gen-wheels.sh" vibevoice "${VERSION}" "${PACKAGES[@]}"
