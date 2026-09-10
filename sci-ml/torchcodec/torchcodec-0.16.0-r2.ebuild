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

inherit cuda distutils-r1

DESCRIPTION="Media decoding for PyTorch, the torchaudio IO backend"
HOMEPAGE="https://github.com/pytorch/torchcodec"
SRC_URI="https://github.com/pytorch/torchcodec/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.gh.tar.gz"

S="${WORKDIR}"/torchcodec-${PV}

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+avif cuda +gif +heic +jpeg +png +webp"

RDEPEND="
	media-video/ffmpeg:=
	=sci-ml/pytorch-2.14*[${PYTHON_SINGLE_USEDEP},cuda?]
	avif? ( media-libs/libavif:= )
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	gif? ( media-libs/giflib:= )
	heic? ( media-libs/libheif:= )
	jpeg? ( media-libs/libjpeg-turbo:= )
	png? ( media-libs/libpng:= )
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
}

src_configure() {
	use cuda && cuda_add_sandbox -w

	# We deliberately link the system ffmpeg rather than upstream's
	# bundled multi-ffmpeg wheel path; upstream gates this behind an
	# acknowledgment because a GPL-built ffmpeg makes the combined
	# work GPL-governed — business as usual for a source distro.
	export I_CONFIRM_THIS_IS_NOT_A_LICENSE_VIOLATION=1

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
	distutils-r1_src_configure
}

python_compile() {
	# The version plugin honors this over version.txt+git probing.
	export BUILD_VERSION="${PV}"
	distutils-r1_python_compile
}
