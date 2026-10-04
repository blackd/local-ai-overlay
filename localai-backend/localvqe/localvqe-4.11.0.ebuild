# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI voice-quality-enhancement backend (denoise/dereverb), built
# from localai-org's LocalVQE at the exact commit this LocalAI release
# pins. The CMake project root is the engine's ggml/ subdirectory, with
# upstream ggml vendored inside it (ggml/vendor/ggml). The build emits
# liblocalvqe.so plus shared libggml*.so (including per-CPU
# libggml-cpu-*.so variants when the engine's GGML_BACKEND_DL loader
# mode is active) — all installed under lib/.
# USE=cuda exceeds LocalAI's own packaging: its backend Makefile builds
# CPU/Vulkan only, but the engine carries a LOCALVQE_CUDA path. HIP has
# no engine code path at all — AMD is served via Vulkan, and USE=rocm is
# omitted via the eclass's LOCALAI_GGML_NO_ROCM gate.

EAPI=8

LOCAL_AI_ENGINE_LIB="liblocalvqe.so"
LOCAL_AI_CUDA_CMAKE_VARS="GGML_CUDA LOCALVQE_CUDA"
LOCAL_AI_VULKAN_CMAKE_VARS="GGML_VULKAN LOCALVQE_VULKAN"
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	-DLOCALVQE_BUILD_SHARED=ON
	-DGGML_BUILD_TESTS=OFF
	-DGGML_BUILD_EXAMPLES=OFF
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON
)
LOCALAI_GGML_NO_ROCM=1

inherit local-ai-ggml-go

# The LocalVQE commit LocalAI v4.11.0 builds against. Source of truth:
# backend/go/localvqe/Makefile (LOCALVQE_VERSION) at the upstream
# release tag; the ggml pin is that commit's ggml/vendor/ggml gitlink.
LOCALVQE_COMMIT="b0f0378a450e87c871b85689554801601ca56d98"
GGML_COMMIT="c044a8eeae2591faa0950c8b5e514cbc4bbfc4ca"

DESCRIPTION="LocalAI voice-quality-enhancement backend (LocalVQE gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/localai-org/LocalVQE/archive/${LOCALVQE_COMMIT}.tar.gz -> LocalVQE-${LOCALVQE_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/localvqe"
CMAKE_USE_DIR="${S}/sources/LocalVQE/ggml"

LICENSE="MIT Apache-2.0"
KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" ggml/vendor/ggml )
	local-ai-backend_engine_unpack "LocalVQE-${LOCALVQE_COMMIT}.tar.gz" LocalVQE "${ggml[@]}"
}

src_install() {
	# Shared-libs layout: liblocalvqe.so plus every libggml*.so it loads
	# (the engine's runtime loader may pick among CPU variants), symlink
	# chains preserved, all under lib/.
	local-ai-backend_gen_run_sh "${PN}" \
		"LOCALVQE_LIBRARY=lib/${LOCAL_AI_ENGINE_LIB}" "LD_LIBRARY_PATH=lib"
	local-ai-backend_install "${PN}" "${S}/${PN}"
	local libdir="${LOCAL_AI_BACKENDS_DIR#${EPREFIX}}/${PN}/lib"
	dodir "${libdir}"
	find "${BUILD_DIR}" \( -name 'liblocalvqe.so*' -o -name 'libggml*.so*' \) \
		-exec cp -a {} "${ED}${libdir}/" \; || die
}
