# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI audio-event-detection backend (CED tagging models), built from
# localai-org's ced.cpp at the exact commit this LocalAI release pins.
# The dlopen-able library is the engine's own target (libced.so) and the
# Go side (purego) opens it by bare soname — run.sh provides
# LD_LIBRARY_PATH instead of an engine-specific variable.

EAPI=8

LOCAL_AI_ENGINE_LIB="libced.so"
# ced.cpp FORCE-overwrites the bare GGML_* toggles from its own gated
# options, so only the prefixed names select acceleration.
LOCAL_AI_CUDA_CMAKE_VARS="CED_GGML_CUDA"
LOCAL_AI_VULKAN_CMAKE_VARS="CED_GGML_VULKAN"
LOCAL_AI_HIP_CMAKE_VARS="CED_GGML_HIP"
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	-DCED_SHARED=ON
	-DCED_BUILD_CLI=OFF
	-DCED_BUILD_TESTS=OFF
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON
)

inherit local-ai-ggml-go

# The ced.cpp commit LocalAI v4.10.0 builds against. Source of truth:
# backend/go/ced/Makefile (CED_VERSION) at the upstream release tag; the
# ggml pin is that commit's third_party/ggml gitlink (same ggml commit
# as app-local-ai/parakeet-cpp — the distfile is shared).
CED_COMMIT="db5aae02973a745722d6fbd2157cab1999106777"
GGML_COMMIT="e705c5fed490514458bdd2eaddc43bd098fcce9b"

DESCRIPTION="LocalAI audio-event-detection backend (ced.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/localai-org/ced.cpp/archive/${CED_COMMIT}.tar.gz -> ced.cpp-${CED_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/ced"
CMAKE_USE_DIR="${S}/sources/ced.cpp"

KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" third_party/ggml )
	local-ai-backend_engine_unpack "ced.cpp-${CED_COMMIT}.tar.gz" ced.cpp "${ggml[@]}"
}

src_configure() {
	# Mirrors upstream's cublas build: CUDA graphs alongside the CUDA
	# backend (a plain ggml toggle, not gated behind a CED_* name).
	use cuda && LOCAL_AI_EXTRA_CMAKE_ARGS+=( -DGGML_CUDA_GRAPHS=ON )
	local-ai-ggml_src_configure
}

src_install() {
	# purego dlopens the bare soname; the backend dir itself goes on
	# LD_LIBRARY_PATH (CED_LIBRARY exists only in run.sh's Darwin branch).
	local-ai-backend_gen_run_sh "${PN}" "LD_LIBRARY_PATH=."
	local-ai-backend_install "${PN}" "${BUILD_DIR}/${LOCAL_AI_ENGINE_LIB}" "${S}/${PN}"
}
