# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# torchaudio for the system sci-ml/pytorch. Upstream is in maintenance
# mode: the newest tag is v2.11.0 while pytorch is at 2.13, so this
# builds a version pair upstream never shipped together — accepted
# under the overlay's system-torch policy, with each consuming backend
# audited individually. This torchaudio generation delegates load/save
# entirely to sci-ml/torchcodec (an ImportError names it at call time
# when absent); the sox/ffmpeg media backends are gone.
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
DISTUTILS_USE_PEP517=setuptools
DISTUTILS_EXT=1
# The eclass's amdgpu_targets_* IUSE list is keyed off this; 7.2 =
# the system ROCm. Portage filters the AMDGPU_TARGETS env var to
# flags present in IUSE, so without the eclass globals
# get_amdgpu_flags would return nothing.
ROCM_VERSION=7.2
inherit cuda distutils-r1 multiprocessing rocm

DESCRIPTION="Audio processing library for PyTorch"
HOMEPAGE="https://github.com/pytorch/audio"
SRC_URI="https://github.com/pytorch/audio/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.gh.tar.gz"

S="${WORKDIR}"/audio-${PV}

LICENSE="BSD-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="cuda rocm"

REQUIRED_USE="
	?? ( cuda rocm )
	rocm? ( ${ROCM_REQUIRED_USE} )
"

RDEPEND="
	=sci-ml/pytorch-2.12*[${PYTHON_SINGLE_USEDEP},cuda(-)?,rocm(-)?]
	$(python_gen_cond_dep 'sci-ml/torchcodec[${PYTHON_SINGLE_USEDEP}]')
"

# The test suite needs network-fetched fixtures.
RESTRICT="test"

src_prepare() {
	use cuda && cuda_src_prepare
	distutils-r1_src_prepare
}

src_configure() {
	rocm_add_sandbox -w
	distutils-r1_src_configure
}

python_compile() {
	addpredict /dev/kfd
	addpredict /dev/random

	export BUILD_VERSION="${PV}"
	export USE_CUDA=$(usex cuda 1 0)
	export USE_ROCM=$(usex rocm 1 0)
	export BUILD_CUDA_CTC_DECODER=$(usex cuda 1 0)
	export USE_OPENMP=1

	if use rocm; then
		# Gentoo installs ROCm under /usr (same export pytorch's own
		# ebuild uses; the default probe is /opt/rocm).
		export ROCM_PATH=/usr
		export PYTORCH_ROCM_ARCH="$(get_amdgpu_flags)"
	fi

	MAX_JOBS="$(get_makeopts_jobs)" \
		distutils-r1_python_compile -j1
}
