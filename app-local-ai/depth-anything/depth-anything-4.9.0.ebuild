# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI monocular depth-estimation backend built on depth-anything.cpp
# (Depth Anything V2/V3 in ggml): unlike the other Go backends there is no
# separate C shim — the wrapper builds the engine's own libdepthanything
# shared library and the CGO-free Go gRPC server dlopens it directly.

EAPI=8

LOCAL_AI_ENGINE_LIB="libdepthanything.so"
LOCAL_AI_CMAKE_TARGET="depthanything"
# The engine FORCE-overrides GGML_CUDA/GGML_VULKAN/GGML_METAL from its own
# DA_GGML_* options, so those toggles must use the DA names; GGML_HIP is
# not wrapped and passes straight through to ggml.
LOCAL_AI_CUDA_CMAKE_VARS="DA_GGML_CUDA"
LOCAL_AI_VULKAN_CMAKE_VARS="DA_GGML_VULKAN"
# The da3-cli tool is not needed for the backend.
LOCAL_AI_EXTRA_CMAKE_ARGS=( -DDA_BUILD_CLI=OFF )

inherit local-ai-ggml-go

# The depth-anything.cpp commit LocalAI v4.9.0 builds against. Source of
# truth: backend/go/depth-anything-cpp/Makefile (DEPTHANYTHING_VERSION) at
# the upstream release tag; the ggml pin is that commit's third_party/ggml
# submodule gitlink (ggml-org's mainline ggml).
DEPTHANYTHING_COMMIT="54abd5c0abfd1f394e01cb3c38f2e3af4daedf85"
GGML_COMMIT="eced84c86f8b012c752c016f7fe789adea168e1e"

DESCRIPTION="LocalAI depth-estimation backend (depth-anything.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/mudler/depth-anything.cpp/archive/${DEPTHANYTHING_COMMIT}.tar.gz -> depth-anything.cpp-${DEPTHANYTHING_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/depth-anything-cpp"

KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" third_party/ggml )
	local-ai-backend_engine_unpack "depth-anything.cpp-${DEPTHANYTHING_COMMIT}.tar.gz" depth-anything.cpp "${ggml[@]}"
}
