# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# PyTorch's media decoder — the IO backend torchaudio 2.11 delegates
# load/save to. Builds against the system ffmpeg (upstream's wheels
# instead bundle several ffmpeg majors via an env-gated path we leave
# off). torch >= 2.11 is officially supported, so the system 2.13
# pairing is in-matrix. Video and audio format coverage follows the
# system ffmpeg's own USE flags; the image codecs are gated here.
#
# Revision ladder: each -rN pairs this build with one pytorch
# generation the tree carries (libtorch has no ABI subslot, so hard
# version pins are the only resolver-enforced pairing). Portage picks
# the revision whose pin is satisfiable, and a torch generation
# upgrade forces the switch — an ABI rebuild — atomically. When the
# tree gains a new pytorch, append the next -rN with its pin; the
# nightly dep-bump issue for sci-ml/pytorch is the reminder.

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
DISTUTILS_SINGLE_IMPL=1
DISTUTILS_USE_PEP517=scikit-build-core
DISTUTILS_EXT=1

ROCM_SKIP_GLOBALS=1
inherit cuda distutils-r1 rocm

DESCRIPTION="Media decoding for PyTorch, the torchaudio IO backend"
HOMEPAGE="https://github.com/pytorch/torchcodec"
SRC_URI="https://github.com/pytorch/torchcodec/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.gh.tar.gz"

S="${WORKDIR}"/torchcodec-${PV}

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+avif cuda +gif +heic +jpeg +png rocm +webp"

REQUIRED_USE="
	?? ( cuda rocm )
"

RDEPEND="
	media-video/ffmpeg:=
	=sci-ml/pytorch-2.13*[${PYTHON_SINGLE_USEDEP},cuda?,rocm?]
	avif? ( media-libs/libavif:= )
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	gif? ( media-libs/giflib:= )
	heic? ( media-libs/libheif:= )
	jpeg? ( media-libs/libjpeg-turbo:= )
	png? ( media-libs/libpng:= )
	rocm? ( dev-util/hip:= )
	webp? ( media-libs/libwebp:= )
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	$(python_gen_cond_dep 'dev-python/pybind11[${PYTHON_USEDEP}]')
"

# The test suite needs network-fetched media fixtures.
RESTRICT="test"

src_prepare() {
	use cuda && cuda_src_prepare
	distutils-r1_src_prepare

	# The AVIF path has no system-library branch: it unconditionally
	# FetchContent-downloads a prebuilt decode-only libavif from
	# upstream's S3 (their wheel-bundling mechanism). The fetch file's
	# whole contract is to define the `avif` CMake target, which
	# libavif's own installed package config provides under exactly
	# that name — so the file becomes the find_package.
	if use avif; then
		cat <<-EOF > src/torchcodec/_core/fetch_avif_from_s3.cmake || die
		find_package(libavif CONFIG REQUIRED)
		EOF
	fi

	# GIF: no system-library branch upstream either — a vendored
	# decode-only giflib subset is compiled into the image library.
	# The decoder only uses the standard public DGif* API, so rewire
	# it to the system giflib: swap the vendored source list for
	# CMake's stock FindGIF, link GIF::GIF, include the system header.
	# sed no-ops silently, hence the anchor greps.
	if use gif; then
		sed -i \
			-e 's|list(APPEND image_library_sources ${TORCHCODEC_GIFLIB_SOURCES})|find_package(GIF 5 REQUIRED)|' \
			-e 's|target_compile_definitions(${image_library_name} PRIVATE TORCHCODEC_ENABLE_GIF=1)|&\n        target_link_libraries(${image_library_name} PRIVATE GIF::GIF)|' \
			src/torchcodec/_core/CMakeLists.txt || die
		grep -q 'find_package(GIF 5 REQUIRED)' \
			src/torchcodec/_core/CMakeLists.txt \
			|| die "giflib source-list anchor moved"
		grep -q 'GIF::GIF' src/torchcodec/_core/CMakeLists.txt \
			|| die "giflib link anchor moved"
		sed -i 's|"giflib/gif_lib.h"|<gif_lib.h>|' \
			src/torchcodec/_core/DecodeGif.cpp || die
		grep -q '<gif_lib.h>' src/torchcodec/_core/DecodeGif.cpp \
			|| die "gif include anchor moved"
		rm -r src/torchcodec/_core/giflib || die
	fi
}

src_configure() {
	use cuda && cuda_add_sandbox -w

	# We deliberately link the system ffmpeg rather than upstream's
	# bundled multi-ffmpeg wheel path; upstream gates this behind an
	# acknowledgment because a GPL-built ffmpeg makes the combined
	# work GPL-governed — business as usual for a source distro.
	export I_CONFIRM_THIS_IS_NOT_A_LICENSE_VIOLATION=1

	# Gentoo's autotools-built libwebp installs no CMake config;
	# generate one via pkg-config as the tree does (bug #937031).
	# torchcodec links WebP::webp and WebP::webpdemux.
	if use webp; then
		mkdir -p "${T}/cmake" || die
		cat <<-EOF > "${T}/cmake/WebPConfig.cmake" || die
		find_package(PkgConfig REQUIRED)
		pkg_check_modules(WebP REQUIRED IMPORTED_TARGET libwebp)
		pkg_check_modules(WebPDemux REQUIRED IMPORTED_TARGET libwebpdemux)
		add_library(WebP::webp ALIAS PkgConfig::WebP)
		add_library(WebP::webpdemux ALIAS PkgConfig::WebPDemux)
		EOF
	fi

	DISTUTILS_ARGS=(
		-DENABLE_CUDA=$(usex cuda ON OFF)
		-DTORCHCODEC_BUILD_JPEG=$(usex jpeg ON OFF)
		-DTORCHCODEC_BUILD_PNG=$(usex png ON OFF)
		-DTORCHCODEC_BUILD_WEBP=$(usex webp ON OFF)
		-DTORCHCODEC_BUILD_AVIF=$(usex avif ON OFF)
		-DTORCHCODEC_BUILD_GIF=$(usex gif ON OFF)
		-DTORCHCODEC_BUILD_HEIC=$(usex heic ON OFF)
		# nvJPEG rides the CUDA toolchain.
		-DTORCHCODEC_BUILD_NVJPEG=$(usex cuda ON OFF)
	)
	use webp && DISTUTILS_ARGS+=( -DWebP_DIR="${T}/cmake" )
	distutils-r1_src_configure
}

python_compile() {
	# The version plugin honors this over version.txt+git probing.
	export BUILD_VERSION="${PV}"

	if use rocm; then
		# scikit-build-core runs cmake HERE, not in src_configure.
		# On a rocm-built pytorch, torch's exported config pulls in
		# Caffe2's LoadHIP.cmake, which silently skips defining
		# hip::host unless ROCM_PATH names a real ROCm root (its
		# default probe is /opt/rocm; Gentoo's lives in /usr — the
		# same value pytorch's own ebuild uses) — configure then
		# dies at Caffe2Targets.cmake.
		local -x ROCM_PATH=/usr
		# LoadHIP also wants the GPU arch list; feed it the same
		# AMDGPU_TARGETS the system pytorch was built with (without
		# it, LoadHIP shells out to rocm_agent_enumerator, which
		# needs GPU device access the sandbox doesn't grant).
		local -x PYTORCH_ROCM_ARCH="$(get_amdgpu_flags)"
	fi

	distutils-r1_python_compile
}
