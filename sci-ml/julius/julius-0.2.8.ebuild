# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Resampling, FFT convolution, low-pass and band splitting as
# differentiable torch modules. Dependency of descript-audiotools and
# torch-audiomentations. torch is the only runtime dependency.

EAPI=8

DISTUTILS_USE_PEP517=hatchling
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="DSP sweets for PyTorch: resampling and FFT convolutions, differentiable"
HOMEPAGE="https://github.com/adefossez/julius https://pypi.org/project/julius/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]"

distutils_enable_tests pytest

# Compares against resampy at module import; resampy is not packaged.
# The resample module's doctests still run through tests/test_doc.py.
EPYTEST_IGNORE=( tests/test_resample.py )
