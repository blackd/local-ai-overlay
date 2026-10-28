# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# lucidrains' vector quantisation layers (VQ, residual VQ, FSQ, LFQ,
# SimVQ, ...) for torch. Dependency of neucodec and ACE-Step.

EAPI=8

DISTUTILS_USE_PEP517=hatchling
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Vector Quantization (VQ, residual VQ, FSQ, LFQ) layers for PyTorch"
HOMEPAGE="https://github.com/lucidrains/vector-quantizer-pytorch https://pypi.org/project/vector-quantize-pytorch/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
# No test-suite in the sdist.
RESTRICT="test"

RDEPEND="
	>=sci-ml/pytorch-2.4[${PYTHON_SINGLE_USEDEP}]
	>=sci-ml/torch-einops-utils-0.1.42[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		>=dev-python/einops-0.8.0[${PYTHON_USEDEP}]
		>=dev-python/einx-0.3.0[${PYTHON_USEDEP}]
		dev-python/loguru[${PYTHON_USEDEP}]
	')
"
