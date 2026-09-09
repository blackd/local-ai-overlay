#!/bin/bash
# gRPC stubs for app-local-ai/python-common: backend_pb2*.py generated
# from backend/backend.proto — identical for every python backend.
# The tree has no dev-python/grpcio-tools and the system grpc builds no
# python plugin, so they are generated here. grpcio-tools is pinned to
# the grpcio version the backends' common requirements name, keeping
# the generated version guard at or below the system dev-python/grpcio.

set -euo pipefail

VERSION="${1:?usage: gen-python-common-distfiles.sh <version>}"
WORK=$(mktemp -d /tmp/python-common-distfiles.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

# The proto must be byte-identical to the tarball the backends compile
# against: tags can move, so fetch the full source tarball and verify
# it against the digest the overlay already pins before extracting.
curl -fsSL "https://github.com/mudler/LocalAI/archive/refs/tags/v${VERSION}.tar.gz" \
	-o "$WORK/local-ai-${VERSION}.tar.gz"
recorded=$(grep -h "^DIST local-ai-${VERSION}.tar.gz " ../app-local-ai/*/Manifest | awk '{print $7}' | sort -u | head -n1)
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

tar -C "$WORK" -cJf "$OUT/python-common-${VERSION}-stubs.tar.xz" stubs

echo "Created in $OUT:"
ls -lh "$OUT/python-common-${VERSION}-stubs.tar.xz"
