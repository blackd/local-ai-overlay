# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# lucidrains' torch helper functions (shape, device, save/load, stable
# softmax), the common dependency of vector-quantize-pytorch and
# local-attention. numpy and packaging are imported at module level
# but missing from the sdist's dependency list.

EAPI=8

DISTUTILS_USE_PEP517=hatchling
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Torch utility functions shared by lucidrains' libraries"
HOMEPAGE="https://github.com/lucidrains/torch-einops-utils https://pypi.org/project/torch-einops-utils/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=sci-ml/pytorch-2.5[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		>=dev-python/einops-0.8.1[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/packaging[${PYTHON_USEDEP}]
	')
"

distutils_enable_tests pytest
