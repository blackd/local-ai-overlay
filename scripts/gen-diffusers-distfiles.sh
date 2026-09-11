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
WORK=$(mktemp -d /tmp/diffusers-distfiles.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

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

mkdir "$WORK/wheels"
for p in "${PACKAGES[@]}"; do
	# pip wheel, not pip download: sdist-only packages would otherwise
	# land as .tar.gz the ebuild's offline *.whl install never sees
	# (bit fish-speech via randomname/argbind).
	python3 -m pip wheel --no-deps --wheel-dir "$WORK/wheels" "$p"
done
tar -C "$WORK" -cJf "$OUT/diffusers-${VERSION}-wheels.tar.xz" wheels

echo "Created in $OUT:"
ls -lh "$OUT/diffusers-${VERSION}-wheels.tar.xz"
