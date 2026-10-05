#!/bin/bash
# Wheels for the venv layer of localai-backend/speaker-recognition.
# Parity rule: the venv ships everything upstream's install resolves,
# MINUS what the portage tree provides as system packages — leaving
# speechbrain, HyperPyYAML, and the ruamel.yaml HyperPyYAML caps
# below 0.19 (the tree's 0.19 dropped the API it uses; the venv wheel
# shadows it — its C accelerator is the tree's ruamel-yaml-clib, which
# keeps the 0.18-era API). torch, torchaudio, transformers, onnxruntime,
# numpy, scipy, soundfile, joblib, sentencepiece and the huggingface
# stack are all tree packages reaching the venv via
# --system-site-packages.
# Snapshot source: pip install --dry-run --report of speechbrain.
# Everything is BUILT from PyPI sdists (nobin:), never taken prebuilt.
# Upload the result as an asset of a release tagged
# speaker-recognition-v<version> on this repository.

set -euo pipefail

VERSION="${1:?usage: gen-speaker-recognition-distfiles.sh <version>}"

PACKAGES=(
	"nobin:speechbrain==1.1.1"
	"nobin:HyperPyYAML==1.2.3"
	"nobin:ruamel.yaml==0.18.17"
)

bash "$(dirname "$(realpath "$0")")/gen-wheels.sh" speaker-recognition "${VERSION}" "${PACKAGES[@]}"
