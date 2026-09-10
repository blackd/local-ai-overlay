# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# torchaudio for the system sci-ml/pytorch. Upstream is in maintenance
# mode: the newest tag is v2.11.0 while the system pytorch is newer,
# so this builds a version pair upstream never shipped together —
# accepted under the overlay's system-torch policy, with each
# consuming backend audited individually. This torchaudio generation
# delegates load/save entirely to sci-ml/torchcodec (an ImportError
# names it at call time when absent); the sox/ffmpeg media backends
# are gone. The pytorch revision ladder and the shared
# torch-extension boilerplate live in local-ai-torch.eclass.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
LOCAL_AI_TORCH_GEN=2.12
inherit local-ai-torch multiprocessing

DESCRIPTION="Audio processing library for PyTorch"
HOMEPAGE="https://github.com/pytorch/audio"
SRC_URI="https://github.com/pytorch/audio/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.gh.tar.gz"

S="${WORKDIR}"/audio-${PV}

LICENSE="BSD-2"
KEYWORDS="~amd64"

RDEPEND="
	$(python_gen_cond_dep 'sci-ml/torchcodec[${PYTHON_SINGLE_USEDEP}]')
"
DEPEND="${RDEPEND}"

python_compile() {
	# torch import probes GPU and entropy devices at build time.
	addpredict /dev/kfd
	addpredict /dev/random

	export USE_CUDA=$(usex cuda 1 0)
	export USE_ROCM=$(usex rocm 1 0)
	export BUILD_CUDA_CTC_DECODER=$(usex cuda 1 0)
	export USE_OPENMP=1

	MAX_JOBS="$(get_makeopts_jobs)" \
		local-ai-torch_python_compile -j1
}
