# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI skeleton-animation backend (/3d/animate): NVIDIA's Kimodo
# ported to C++/GGML, built from localai-org's kimodo.cpp at the exact
# commit this LocalAI release pins. The wrapper CMake FORCEs
# BUILD_SHARED_LIBS: the Go server (purego) loads libkimodo.so which
# links separate libggml*.so — installed under lib/ with symlink chains
# intact (the trellis2cpp layout). The engine's only accelerator is
# Vulkan (no CUDA/HIP code paths), so those eclass flags are
# masked in profiles/package.use.mask rather than silently ignored.

EAPI=8

LOCAL_AI_CMAKE_TARGET="kimodo"
LOCAL_AI_ENGINE_LIB="libkimodo.so"
LOCAL_AI_VULKAN_CMAKE_VARS="KIMODO_ENABLE_VULKAN"

inherit local-ai-ggml-go

# The kimodo.cpp commit LocalAI v4.11.0 builds against. Source of truth:
# backend/go/kimodocpp/Makefile (KIMODO_VERSION) at the upstream release
# tag; the ggml pin is that commit's ggml gitlink.
KIMODO_COMMIT="5679ff19ba0a522c0b0516e9a9d402fe1af2c027"
GGML_COMMIT="8c63e70982c95ceb862e3a1073a2c1beef75d60a"

DESCRIPTION="LocalAI skeleton-animation backend (kimodo.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/localai-org/kimodo.cpp/archive/${KIMODO_COMMIT}.tar.gz -> kimodo.cpp-${KIMODO_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/kimodocpp"

LICENSE="MIT Apache-2.0"
KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" ggml )
	local-ai-backend_engine_unpack "kimodo.cpp-${KIMODO_COMMIT}.tar.gz" kimodo.cpp "${ggml[@]}"
}

src_install() {
	# Shared-libs layout: libkimodo.so plus the libggml*.so it links,
	# symlink chains preserved, all under lib/.
	local-ai-backend_gen_run_sh "${PN}" \
		"KIMODO_LIBRARY=lib/${LOCAL_AI_ENGINE_LIB}" "LD_LIBRARY_PATH=lib"
	local-ai-backend_install "${PN}" "${S}/${PN}"
	local libdir="${LOCAL_AI_BACKENDS_DIR#${EPREFIX}}/${PN}/lib"
	dodir "${libdir}"
	find "${BUILD_DIR}" \( -name 'libkimodo.so*' -o -name 'libggml*.so*' \) \
		-exec cp -a {} "${ED}${libdir}/" \; || die
}
