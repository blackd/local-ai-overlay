#!/bin/bash
# Wheels for the venv layer of app-local-ai/fish-speech. Parity rule:
# the venv ships everything upstream's install.sh resolves (the full
# fish-speech pyproject, train/webui extras included), MINUS what the
# portage tree or this overlay provides as system packages — those
# reach the venv via --system-site-packages. The list below is the
# full resolution snapshot (pip install --dry-run --report of the
# prepared pyproject) with the system-provided names removed; the
# planned weekly refresh workflow re-resolves it. Upstream's own
# deviations are replicated, not invented here: prepare-source.sh
# strips the torch/torchaudio pins and pyaudio; we additionally relax
# pydantic==2.9.2 to the tree's pydantic (resolution- and API-checked;
# the tree pydantic builds pydantic_core in-package). wandb and
# tensorboard-data-server are PARKED: their wheels ship prebuilt
# Go/Rust binaries, which the from-source rule cannot accept — pending
# a decision (source-built cores vs sanctioned exception).
# Upload the result as an asset of a release tagged
# fish-speech-v<version> on this repository.

set -euo pipefail

VERSION="${1:?usage: gen-fish-speech-distfiles.sh <version>}"
WORK=$(mktemp -d /tmp/fish-speech-distfiles.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

PACKAGES=(
	argbind==0.3.9
	baize==0.23.1
	datasets==2.18.0
	descript-audio-codec==1.0.0
	descript-audiotools==0.7.2
	einops==0.8.2
	einx==0.2.2
	ffmpy==1.0.0
	fire==0.7.1
	flatten-dict==0.5.0
	frozendict==2.4.7
	gradio==6.17.3
	gradio-client==2.5.0
	groovy==0.1.2
	hf-gradio==0.4.1
	huggingface-hub==0.36.2
	hydra-core==1.3.6
	importlib-resources==7.1.0
	julius==0.2.8
	kui==1.14.1
	librosa==1.0.0
	lightning==2.6.6
	lightning-utilities==0.15.3
	loralib==0.1.2
	modelscope==1.17.1
	omegaconf==2.3.1
	opencc-python-reimplemented==0.1.7
	pyarrow-hotfix==0.7
	pydub==0.25.1
	pyloudnorm==0.2.0
	pyrootutils==1.0.4
	pystoi==0.4.1
	pytorch-lightning==2.6.6
	randomname==0.2.1
	resampy==0.4.3
	safehttpx==0.1.7
	sentry-sdk==2.69.1
	silero-vad==6.2.1
	tensorboard==2.20.0
	torch-stoi==0.2.3
	torchmetrics==1.9.0
	transformers==4.57.3
)

mkdir "$WORK/wheels"
for p in "${PACKAGES[@]}"; do
	python3 -m pip download --no-deps --dest "$WORK/wheels" "$p"
done
tar -C "$WORK" -cJf "$OUT/fish-speech-${VERSION}-wheels.tar.xz" wheels

echo "Created in $OUT:"
ls -lh "$OUT/fish-speech-${VERSION}-wheels.tar.xz"
