# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI 3D-generation backend (/3d/generations): Microsoft's TRELLIS
# image/text-to-3D ported to C++/GGML, built from localai-org's
# trellis2cpp at the exact commit this LocalAI release pins. The engine
# target has no explicit library type, so BUILD_SHARED_LIBS=ON (after
# the eclass's OFF default) produces libtrellis2.so plus the shared
# libggml*.so it links — installed kimodo-style under lib/.
# USE=cgal enables the CGAL Alpha Wrap print-remeshing feature against
# the system CGAL (upstream's alternative is a network-fetching dep
# script, TRELLIS2_FETCH_PRINT_REMESH_DEPS, kept OFF).

EAPI=8

LOCAL_AI_CMAKE_TARGET="trellis2"
LOCAL_AI_ENGINE_LIB="libtrellis2.so"
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	-DBUILD_SHARED_LIBS=ON
	-DTRELLIS2_BUILD_EXAMPLES=OFF
	-DTRELLIS2_BUILD_TESTS=OFF
	-DTRELLIS2_FETCH_PRINT_REMESH_DEPS=OFF
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON
)
# hipcc HIP-compiles the CGAL/boost remesh TU into a frexp ambiguity;
# upstream's own hipblas recipe exports ROCm clang for this engine.
LOCAL_AI_ROCM_CLANG=1

inherit local-ai-ggml-go

# The trellis2cpp commit LocalAI v4.11.0 builds against. Source of
# truth: backend/go/trellis2cpp/Makefile (TRELLIS2CPP_VERSION) at the
# upstream release tag; the ggml pin is that commit's gitlink
# (PABannier's fork — same commit as localai-backend/sam3-cpp, the
# distfile is shared).
TRELLIS2_COMMIT="2f3e6e26edbbaaf8ce93d092f16f46968a366a6a"
GGML_COMMIT="331b9cba52b23d895bc4ad218c007eb5e667540f"

DESCRIPTION="LocalAI 3D-generation backend (trellis2cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/localai-org/trellis2cpp/archive/${TRELLIS2_COMMIT}.tar.gz -> trellis2cpp-${TRELLIS2_COMMIT}.tar.gz
	https://github.com/PABannier/ggml/archive/${GGML_COMMIT}.tar.gz -> pabannier-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/trellis2cpp"
CMAKE_USE_DIR="${S}/sources/trellis2cpp"

KEYWORDS="~amd64"
IUSE="+cgal"

RDEPEND+="
	cgal? (
		sci-mathematics/cgal:=
		dev-libs/boost:=
	)
"
DEPEND+="
	cgal? (
		sci-mathematics/cgal:=
		dev-libs/boost:=
	)
"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "pabannier-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" ggml )
	local-ai-backend_engine_unpack "trellis2cpp-${TRELLIS2_COMMIT}.tar.gz" trellis2cpp "${ggml[@]}"
}

src_configure() {
	# Gate the auto-detected CGAL feature on the flag instead of leaving
	# an automagic dependency.
	LOCAL_AI_EXTRA_CMAKE_ARGS+=( -DTRELLIS2_CGAL=$(usex cgal) )
	local-ai-ggml_src_configure
}

src_install() {
	# Shared-libs layout: libtrellis2.so plus the libggml*.so it links,
	# symlink chains preserved, all under lib/.
	local-ai-backend_gen_run_sh "${PN}" \
		"TRELLIS2_LIBRARY=lib/${LOCAL_AI_ENGINE_LIB}" "LD_LIBRARY_PATH=lib"
	local-ai-backend_install "${PN}" "${S}/${PN}"
	local libdir="${LOCAL_AI_BACKENDS_DIR#${EPREFIX}}/${PN}/lib"
	dodir "${libdir}"
	find "${BUILD_DIR}" \( -name 'libtrellis2.so*' -o -name 'libggml*.so*' \) \
		-exec cp -a {} "${ED}${libdir}/" \; || die
}
