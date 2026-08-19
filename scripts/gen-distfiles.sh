#!/usr/bin/env bash
# Generate the dependency tarballs the LocalAI overlay ebuilds need.
#
# Portage builds run with no network access, so anything upstream's build
# would download must be packed ahead of time. This script produces, for a
# given LocalAI release:
#
#   local-ai-<v>-deps.tar.xz          Go module cache (go-module.eclass format)
#   local-ai-<v>-node_modules.tar.xz  npm dependencies of the React web UI
#   local-ai-<v>-prebuilt.tar.xz      the two generated protobuf Go files
#
# The node_modules and prebuilt tarball paths are rooted at the LocalAI
# source tree top level, so ebuilds unpack them directly inside ${S}; the
# deps tarball is rooted at go-mod/ as go-module.eclass expects. Upload the
# results manually.
#
# Usage: gen-distfiles.sh <localai-version>
# Example: gen-distfiles.sh 4.8.2
set -euo pipefail

VERSION=${1:?usage: gen-distfiles.sh <localai-version>}

OUT=$(pwd)/distfiles-out
WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${OUT}"

echo ">>> Fetching LocalAI v${VERSION}"
curl -fL "https://github.com/mudler/LocalAI/archive/refs/tags/v${VERSION}.tar.gz" -o "${WORK}/local-ai.tar.gz"
tar -C "${WORK}" -xf "${WORK}/local-ai.tar.gz"
SRC="${WORK}/LocalAI-${VERSION}"

# The protobuf plugin versions are pinned in upstream's Makefile
# (install-go-tools target). Read them from the downloaded source so the
# generated code always matches the release being packaged, with nothing to
# update here at version bumps.
PROTOC_GEN_GO_VERSION=$(grep -o 'cmd/protoc-gen-go@[^[:space:]]*' "${SRC}/Makefile" | cut -d@ -f2)
PROTOC_GEN_GO_GRPC_VERSION=$(grep -o 'cmd/protoc-gen-go-grpc@[^[:space:]]*' "${SRC}/Makefile" | cut -d@ -f2)
if [[ -z ${PROTOC_GEN_GO_VERSION} || -z ${PROTOC_GEN_GO_GRPC_VERSION} ]]; then
	echo "ERROR: could not read the protoc plugin pins from ${SRC}/Makefile" >&2
	exit 1
fi
echo ">>> plugin pins: protoc-gen-go@${PROTOC_GEN_GO_VERSION}, protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VERSION}"

echo ">>> Go module cache (go-module.eclass -deps format)"
# The go-mod/ directory name is mandated by go-module.eclass: it points
# GOMODCACHE at ${WORKDIR}/go-mod, so a tarball with this root works with
# the eclass's default src_unpack handling.
( cd "${SRC}" && GOMODCACHE="${SRC}/go-mod" go mod download -modcacherw )
XZ_OPT='-T0 -9' tar -C "${SRC}" -acf "${OUT}/local-ai-${VERSION}-deps.tar.xz" go-mod

echo ">>> React UI node_modules"
( cd "${SRC}/core/http/react-ui" && npm ci )
# vite/rollup/esbuild resolve their native binaries via platform-specific
# optional dependency packages chosen at *install* time. Force both Linux
# arches in so one tarball serves amd64 and arm64 builds.
( cd "${SRC}/core/http/react-ui" && npm install --no-save --force @esbuild/linux-x64 @esbuild/linux-arm64 @rollup/rollup-linux-x64-gnu @rollup/rollup-linux-arm64-gnu )
tar -C "${SRC}" -cJf "${OUT}/local-ai-${VERSION}-node_modules.tar.xz" core/http/react-ui/node_modules

echo ">>> Generated protobuf Go code"
GOBIN="${WORK}/gobin" go install "google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VERSION}"
GOBIN="${WORK}/gobin" go install "google.golang.org/grpc/cmd/protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VERSION}"
mkdir -p "${SRC}/pkg/grpc/proto"
( cd "${SRC}" && PATH="${WORK}/gobin:${PATH}" protoc -I backend --go_out=paths=source_relative:pkg/grpc/proto --go-grpc_out=paths=source_relative:pkg/grpc/proto backend/backend.proto )
tar -C "${SRC}" -cJf "${OUT}/local-ai-${VERSION}-prebuilt.tar.xz" pkg/grpc/proto

echo ">>> Done. Upload these to the distfiles server:"
( cd "${OUT}" && sha256sum ./*.tar.xz )
