#!/bin/bash
# Wheels and gRPC stubs for app-local-ai/diffusers, the venv layer of
# the first python backend. Everything compiled (torch, tokenizers,
# safetensors, sentencepiece, opencv, av, grpcio…) comes from system
# packages instead and is EXCLUDED here — hence --no-deps with a
# curated list, not resolver output.
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
	huggingface-hub
	optimum-quanto
)

mkdir "$WORK/wheels"
for p in "${PACKAGES[@]}"; do
	python3 -m pip download --no-deps --dest "$WORK/wheels" "$p"
done

# The gRPC stubs: the tree has no dev-python/grpcio-tools and the
# system grpc builds no python plugin, so generate backend_pb2*.py here
# and ship them alongside the wheels. grpcio-tools is pinned to the
# grpcio version the backends' common requirements name, keeping the
# generated version guard at or below the system dev-python/grpcio.
#
# The proto must be byte-identical to the tarball the ebuild compiles:
# tags can move, so fetch the full source tarball and verify it against
# the digest the overlay already pins before extracting the proto.
curl -fsSL "https://github.com/mudler/LocalAI/archive/refs/tags/v${VERSION}.tar.gz" \
	-o "$WORK/local-ai-${VERSION}.tar.gz"
recorded=$(grep -h "^DIST local-ai-${VERSION}.tar.gz " ../app-local-ai/*/Manifest | awk '{print $6}' | sort -u | head -n1)
actual=$(sha512sum "$WORK/local-ai-${VERSION}.tar.gz" | cut -d' ' -f1)
if [ -z "$recorded" ] || [ "$recorded" != "$actual" ]; then
	echo "local-ai-${VERSION}.tar.gz does not match the Manifest-pinned digest" >&2
	echo "  recorded: ${recorded:-none}" >&2
	echo "  actual:   ${actual}" >&2
	exit 1
fi
tar -xzOf "$WORK/local-ai-${VERSION}.tar.gz" \
	"LocalAI-${VERSION}/backend/backend.proto" > "$WORK/backend.proto"

python3 -m venv "$WORK/genvenv"
"$WORK/genvenv/bin/pip" install --quiet grpcio-tools==1.76.0
mkdir "$WORK/stubs"
"$WORK/genvenv/bin/python" -m grpc_tools.protoc -I "$WORK" \
	--python_out="$WORK/stubs" --grpc_python_out="$WORK/stubs" backend.proto

tar -C "$WORK" -cJf "$OUT/diffusers-${VERSION}-wheels.tar.xz" wheels stubs

echo "Created in $OUT:"
ls -lh "$OUT/diffusers-${VERSION}-wheels.tar.xz"
