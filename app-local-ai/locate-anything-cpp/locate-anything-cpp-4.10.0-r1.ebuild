# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI open-vocabulary detection/grounding backend, built from
# mudler's locate-anything.cpp at the exact commit this LocalAI release
# pins. The engine compiles into a dlopen-able module library loaded by
# a CGO-free Go gRPC server (the ggml-go backend family layout).

EAPI=8

LOCAL_AI_ENGINE_LIB="liblocateanythingcpp.so"
LOCAL_AI_ENGINE_LIB_ENV="LOCATEANYTHING_LIBRARY"
# The engine gates its own code paths behind LA_GGML_* while ggml wants
# the bare toggles — upstream's cublas/vulkan builds set both, mirrored
# here. The hip mapping deliberately DIFFERS from upstream's Makefile:
# it passes GGML_HIPBLAS=ON, but this pin's ggml (ggml-org, modern) only
# knows GGML_HIP — upstream's hipblas build is silently CPU-only. No
# LA_GGML_HIP gate exists; whether the engine's kernels need one is the
# first USE=rocm build's question.
LOCAL_AI_CUDA_CMAKE_VARS="GGML_CUDA LA_GGML_CUDA"
LOCAL_AI_VULKAN_CMAKE_VARS="GGML_VULKAN LA_GGML_VULKAN"
LOCAL_AI_HIP_CMAKE_VARS="GGML_HIP"

inherit local-ai-ggml-go

# The locate-anything.cpp commit LocalAI v4.10.0 builds against. Source
# of truth: backend/go/locate-anything-cpp/Makefile
# (LOCATEANYTHING_VERSION) at the upstream release tag; the ggml pin is
# that commit's third_party/ggml gitlink.
LOCATEANYTHING_COMMIT="77376ab332de918220f7a7e391542eefb5407c9f"
GGML_COMMIT="7142aa6bf9fcaeec0fef8d80fcd90afe4268adf1"

DESCRIPTION="LocalAI open-vocabulary detection backend (locate-anything.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/mudler/locate-anything.cpp/archive/${LOCATEANYTHING_COMMIT}.tar.gz -> locate-anything.cpp-${LOCATEANYTHING_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/locate-anything-cpp"

KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" third_party/ggml )
	local-ai-backend_engine_unpack "locate-anything.cpp-${LOCATEANYTHING_COMMIT}.tar.gz" locate-anything.cpp "${ggml[@]}"
}
