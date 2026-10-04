# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI face-detection/embedding backend (SCRFD/insightface-class
# models), built from mudler's face-detect.cpp at the exact commit this
# LocalAI release pins.
#
# SPECIAL CASE (parakeet.cpp pattern): the engine carries a patch stack
# for its ggml submodule (third_party/ggml-patches, applied by
# upstream's configure hook via git, replayed here with eapply). At
# every bump re-derive BOTH pins and expect the patch content to change.
#
# Unlike the wrapper-module backends, the dlopen-able library is the
# engine's own target (libfacedetect.so) and the Go side (purego) opens
# it by bare soname — run.sh provides LD_LIBRARY_PATH instead of an
# engine-specific variable. Upstream vendors libjpeg-turbo via a
# network-fetching ExternalProject; FACEDETECT_VENDOR_LIBJPEG=OFF
# switches the engine to find_package(JPEG) and the system library.

EAPI=8

LOCAL_AI_ENGINE_LIB="libfacedetect.so"
# face-detect.cpp FORCE-overwrites the bare GGML_* toggles from its own
# gated options, so only the prefixed names select acceleration.
# (FACEDETECT_GGML_CUDNN stays off: upstream enables it only for
# arm64+CUDA13 images — x86 CUDA has no cuDNN and it is a link failure.)
LOCAL_AI_CUDA_CMAKE_VARS="FACEDETECT_GGML_CUDA"
LOCAL_AI_VULKAN_CMAKE_VARS="FACEDETECT_GGML_VULKAN"
LOCAL_AI_HIP_CMAKE_VARS="FACEDETECT_GGML_HIP"
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	-DFACEDETECT_SHARED=ON
	-DFACEDETECT_BUILD_CLI=OFF
	-DFACEDETECT_BUILD_TESTS=OFF
	-DFACEDETECT_VENDOR_LIBJPEG=OFF
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON
)

inherit local-ai-ggml-go

# The face-detect.cpp commit LocalAI v4.11.0 builds against. Source of
# truth: backend/go/face-detect/Makefile (FACEDETECT_VERSION) at the
# upstream release tag; the ggml pin is that commit's third_party/ggml
# gitlink.
FACEDETECT_COMMIT="e22260d5d5490b37b021b7f795079f386d553afd"
GGML_COMMIT="707321c4cf6d21cb4bc831aa8b687dbf01a521ce"

DESCRIPTION="LocalAI face-detection backend (face-detect.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/mudler/face-detect.cpp/archive/${FACEDETECT_COMMIT}.tar.gz -> face-detect.cpp-${FACEDETECT_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/face-detect"
CMAKE_USE_DIR="${S}/sources/face-detect.cpp"

KEYWORDS="~amd64"

RDEPEND+="
	media-libs/libjpeg-turbo:=
"
DEPEND+="
	media-libs/libjpeg-turbo:=
"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" third_party/ggml )
	local-ai-backend_engine_unpack "face-detect.cpp-${FACEDETECT_COMMIT}.tar.gz" face-detect.cpp "${ggml[@]}"
}

src_prepare() {
	# Replay the engine's ggml patch stack (upstream's configure-time git
	# apply fails its .git check on tarballs and only WARNS, silently
	# building unpatched ggml).
	einfo "Applying face-detect.cpp's own third_party/ggml-patches to ggml"
	pushd "${CMAKE_USE_DIR}/third_party/ggml" >/dev/null || die
	eapply "${CMAKE_USE_DIR}"/third_party/ggml-patches/*.patch
	popd >/dev/null || die

	local-ai-ggml_src_prepare
}

src_install() {
	# purego dlopens the bare soname; the backend dir itself goes on
	# LD_LIBRARY_PATH (no FACEDETECT_LIBRARY-style variable exists).
	local-ai-backend_gen_run_sh "${PN}" "LD_LIBRARY_PATH=."
	local-ai-backend_install "${PN}" "${BUILD_DIR}/${LOCAL_AI_ENGINE_LIB}" "${S}/${PN}"
}
