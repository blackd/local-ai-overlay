#!/bin/bash
# Wheels for the venv layer of app-local-ai/rerankers. Parity rule: the
# venv ships everything upstream's install resolves, MINUS what the
# portage tree provides as system packages — which here is everything
# except the rerankers package itself (torch, transformers, accelerate,
# huggingface_hub, sentencepiece, tokenizers, safetensors, typer, rich
# and the pure-python long tail are all tree packages reaching the venv
# via --system-site-packages). Snapshot source: pip install --dry-run
# --report of rerankers[transformers]. rerankers itself is BUILT from
# its PyPI sdist (nobin:), never taken as the prebuilt wheel.
# Upload the result as an asset of a release tagged rerankers-v<version>
# on this repository.

set -euo pipefail

VERSION="${1:?usage: gen-rerankers-distfiles.sh <version>}"

PACKAGES=(
	"nobin:rerankers==0.10.0"
)

bash "$(dirname "$(realpath "$0")")/gen-wheels.sh" rerankers "${VERSION}" "${PACKAGES[@]}"
