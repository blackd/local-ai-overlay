#!/bin/bash
# Wheels for the venv layer of localai-backend/voxcpm. Parity rule: the
# venv ships what upstream's install resolves MINUS tree/overlay
# packages (librosa and einops are dev-python/* here) and MINUS the
# demo/training-only rows (see the ebuild header) — leaving voxcpm
# itself and modelscope + modelscope-hub (the denoiser
# VoxCPM.from_pretrained loads by default; voxcpm floors modelscope at
# >=1.22).
# Everything is BUILT from PyPI sdists (nobin:), never taken prebuilt.
# Upload as an asset of a release tagged voxcpm-v<version>.

set -euo pipefail

VERSION="${1:?usage: gen-voxcpm-distfiles.sh <version>}"

PACKAGES=(
	"nobin:voxcpm==2.0.3"
	"nobin:modelscope==1.40.2"
	"nobin:modelscope-hub==0.4.6"
	# The text normaliser: wetext ships its FST graphs in the sdist (~46M
	# unpacked); contractions is wheel-only on PyPI (pure), so no nobin.
	"nobin:wetext==0.1.8"
	"contractions==0.1.73"
	"nobin:textsearch==0.0.24"
)

bash "$(dirname "$(realpath "$0")")/gen-wheels.sh" voxcpm "${VERSION}" "${PACKAGES[@]}"
