# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI image-generation backend for GGUF-format diffusion models, built
# from stable-diffusion.cpp at the exact commit this LocalAI release pins.
# Upstream publishes CPU, CUDA, Vulkan, and SYCL variants of this backend
# but no ROCm build at all; USE=rocm here fills that gap.

EAPI=8

LOCAL_AI_ENGINE_LIB="libgosd.so"
# sd.cpp wraps the ggml backend toggles in its own option names.
LOCAL_AI_CUDA_CMAKE_VARS="SD_CUDA"
LOCAL_AI_VULKAN_CMAKE_VARS="SD_VULKAN"
LOCAL_AI_HIP_CMAKE_VARS="SD_HIPBLAS"
# ggml RPC backend on, as upstream builds it: generation can be sharded
# across the same rpc-server workers the llama.cpp backend uses.
LOCAL_AI_EXTRA_CMAKE_ARGS=( -DSD_RPC=ON )

inherit local-ai-ggml-go

# The stable-diffusion.cpp commit LocalAI v4.9.0 builds against. Source of
# truth: backend/go/stablediffusion-ggml/Makefile
# (STABLEDIFFUSION_GGML_VERSION) at the upstream release tag; the ggml pin
# is that commit's submodule gitlink (leejet's ggml fork).
SD_COMMIT="de298c225bed97c3f9026b73cd7b71e7879bd41b"
GGML_COMMIT="8e800cef2948046cc47f9db6090491c6128ca42c"

DESCRIPTION="LocalAI image-generation backend (stable-diffusion.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/leejet/stable-diffusion.cpp/archive/${SD_COMMIT}.tar.gz -> stable-diffusion.cpp-${SD_COMMIT}.tar.gz
	https://github.com/leejet/ggml/archive/${GGML_COMMIT}.tar.gz -> leejet-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/stablediffusion-ggml"

KEYWORDS="~amd64 ~arm64"

src_unpack() {
	local-ai-backend_go_unpack

	# The unused thirdparty submodules (libwebp/libwebm, web frontend)
	# stay empty and sd.cpp's cmake correctly treats them as unavailable.
	local ggml=( "leejet-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" ggml )
	local-ai-backend_engine_unpack "stable-diffusion.cpp-${SD_COMMIT}.tar.gz" stablediffusion-ggml.cpp "${ggml[@]}"
}
