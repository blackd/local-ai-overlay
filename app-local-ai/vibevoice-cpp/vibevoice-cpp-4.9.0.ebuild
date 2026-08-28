# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-to-speech backend for Microsoft's VibeVoice model in GGUF
# format, built from mudler's vibevoice.cpp at the exact commit this
# LocalAI release pins.

EAPI=8

LOCAL_AI_ENGINE_LIB="libgovibevoicecpp.so"
# The wrapper CMake project defines its own toggles next to ggml's.
LOCAL_AI_CUDA_CMAKE_VARS="GGML_CUDA VIBEVOICE_GGML_CUDA"
LOCAL_AI_VULKAN_CMAKE_VARS="GGML_VULKAN VIBEVOICE_GGML_VULKAN"
# The engine subdirectory is EXCLUDE_FROM_ALL; this target pulls
# libvibevoice in as its link dependency.
LOCAL_AI_CMAKE_TARGET="govibevoicecpp"

inherit local-ai-ggml-go

# The vibevoice.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/go/vibevoice-cpp/Makefile (VIBEVOICE_CPP_VERSION) at the upstream
# release tag; the ggml pin is that commit's third_party/ggml submodule
# gitlink (ggml-org's mainline ggml).
VIBEVOICE_COMMIT="000e37282bc5bb09edc20f7047a47924122ba3a0"
GGML_COMMIT="8be60f83ec124c31f3a427053c29022e3072f8a4"

DESCRIPTION="LocalAI text-to-speech backend (vibevoice.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/mudler/vibevoice.cpp/archive/${VIBEVOICE_COMMIT}.tar.gz -> vibevoice.cpp-${VIBEVOICE_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/vibevoice-cpp"

KEYWORDS="~amd64 ~arm64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" third_party/ggml )
	local-ai-backend_engine_unpack "vibevoice.cpp-${VIBEVOICE_COMMIT}.tar.gz" vibevoice.cpp "${ggml[@]}"
}
