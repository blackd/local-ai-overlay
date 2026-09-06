# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI speech-to-text backend for NVIDIA's Parakeet models, built from
# mudler's parakeet.cpp at the exact commit this LocalAI release pins.
#
# SPECIAL CASE: the engine carries a patch stack for its ggml submodule
# (third_party/ggml-patches, applied by upstream's configure hook via
# git, replayed here with eapply). At every bump re-derive BOTH pins —
# the engine commit from the backend Makefile AND the ggml gitlink from
# that engine commit — and expect the patch content to change with them;
# the eapply glob picks up whatever the new tarball carries.

EAPI=8

LOCAL_AI_ENGINE_LIB="libparakeet.so"
# parakeet.cpp FORCE-overwrites the bare GGML_* toggles from its own
# gated options, so only the prefixed names select acceleration.
LOCAL_AI_CUDA_CMAKE_VARS="PARAKEET_GGML_CUDA"
LOCAL_AI_VULKAN_CMAKE_VARS="PARAKEET_GGML_VULKAN"
LOCAL_AI_HIP_CMAKE_VARS="PARAKEET_GGML_HIP"
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	-DPARAKEET_SHARED=ON
	-DPARAKEET_BUILD_CLI=OFF
	-DPARAKEET_BUILD_SERVER=OFF
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON
)

inherit local-ai-ggml-go

# The parakeet.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/go/parakeet-cpp/Makefile (PARAKEET_VERSION) at the upstream
# release tag; the ggml pin is that commit's third_party/ggml gitlink.
PARAKEET_COMMIT="e75de9b6b9b688fd293aa22f7e27aa724ea286f8"
GGML_COMMIT="e705c5fed490514458bdd2eaddc43bd098fcce9b"

DESCRIPTION="LocalAI speech-to-text backend (parakeet.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/mudler/parakeet.cpp/archive/${PARAKEET_COMMIT}.tar.gz -> parakeet.cpp-${PARAKEET_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/parakeet-cpp"
CMAKE_USE_DIR="${S}/sources/parakeet.cpp"

KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" third_party/ggml )
	local-ai-backend_engine_unpack "parakeet.cpp-${PARAKEET_COMMIT}.tar.gz" parakeet.cpp "${ggml[@]}"
}

src_prepare() {
	# The engine applies its in-tree ggml patches at configure time via
	# git apply, which the unpacked tarballs cannot satisfy — the script
	# fails its .git check and CMake only WARNS, silently building
	# unpatched ggml. Apply them here instead; the configure-time warning
	# is then harmless.
	einfo "Applying parakeet.cpp's own third_party/ggml-patches to ggml"
	pushd "${CMAKE_USE_DIR}/third_party/ggml" >/dev/null || die
	eapply "${CMAKE_USE_DIR}"/third_party/ggml-patches/*.patch
	popd >/dev/null || die

	local-ai-ggml_src_prepare
}
