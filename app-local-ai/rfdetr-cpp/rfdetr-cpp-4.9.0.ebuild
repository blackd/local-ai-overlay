# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI object-detection backend (RF-DETR), built from localai-org's
# rf-detr.cpp at the exact commit this LocalAI release pins.
#
# SPECIAL CASE: same ggml patch-stack arrangement as parakeet-cpp (see
# INSTRUCTIONS.md), with one difference — the backend's wrapper
# CMakeLists runs the git-requiring apply script with FATAL_ERROR on
# failure, so besides replaying the patches with eapply the script is
# replaced with a no-op. Re-derive both pins at every bump.

EAPI=8

LOCAL_AI_ENGINE_LIB="librfdetrcpp.so"
# The engine gates ggml's toggles behind conditional RFDETR_GGML_*
# options; upstream passes both names, mirror that.
LOCAL_AI_CUDA_CMAKE_VARS="GGML_CUDA RFDETR_GGML_CUDA"
LOCAL_AI_VULKAN_CMAKE_VARS="GGML_VULKAN RFDETR_GGML_VULKAN"
LOCAL_AI_HIP_CMAKE_VARS="GGML_HIP RFDETR_GGML_HIPBLAS"
LOCAL_AI_CMAKE_TARGET="rfdetrcpp"

inherit local-ai-ggml-go

# The rf-detr.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/go/rfdetr-cpp/Makefile (RFDETR_VERSION) at the upstream release
# tag; the ggml pin is that commit's third_party/ggml gitlink. The
# engine's directory is named rt-detr.cpp (pre-rename slug) — the
# wrapper CMakeLists expects it under sources/rt-detr.cpp.
RFDETR_COMMIT="98d0f381b832ef08a608b65c7dd78db066ed8b9a"
GGML_COMMIT="e705c5fed490514458bdd2eaddc43bd098fcce9b"

DESCRIPTION="LocalAI object-detection backend (rf-detr.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/localai-org/rf-detr.cpp/archive/${RFDETR_COMMIT}.tar.gz -> rf-detr.cpp-${RFDETR_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/rfdetr-cpp"

KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" third_party/ggml )
	local-ai-backend_engine_unpack "rf-detr.cpp-${RFDETR_COMMIT}.tar.gz" rt-detr.cpp "${ggml[@]}"
}

src_prepare() {
	local engine="${S}/sources/rt-detr.cpp"

	einfo "Applying rt-detr.cpp's own third_party/ggml-patches to ggml"
	pushd "${engine}/third_party/ggml" >/dev/null || die
	eapply "${engine}"/third_party/ggml-patches/*.patch
	popd >/dev/null || die
	# The wrapper CMakeLists FATAL_ERRORs if this git-requiring script
	# fails; the patches are already in, so make it a success no-op.
	printf '#!/usr/bin/env bash\n# patches pre-applied by the ebuild\nexit 0\n' \
		> "${engine}/scripts/apply_ggml_patches.sh" || die

	local-ai-ggml_src_prepare
}
