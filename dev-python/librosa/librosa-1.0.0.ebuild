# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Audio analysis library; pure python on top of numba/scipy/soxr. Was a
# venv wheel of three python backends (fish-speech, vibevoice, voxcpm),
# all at 1.0.0 — one system copy instead. Dependency floors from the
# sdist; numba/llvmlite/soxr are this overlay's own packages.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Python library for audio and music analysis"
HOMEPAGE="https://librosa.org https://github.com/librosa/librosa"

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"

# Tests need the librosa test-data repository (network) — not run.
RESTRICT="test"

RDEPEND="
	>=dev-python/decorator-5.2.1[${PYTHON_USEDEP}]
	>=dev-python/joblib-1.2[${PYTHON_USEDEP}]
	>=dev-python/lazy-loader-0.3[${PYTHON_USEDEP}]
	>=dev-python/msgpack-1.0.5[${PYTHON_USEDEP}]
	>=dev-python/numba-0.61.0[${PYTHON_USEDEP}]
	>=dev-python/numpy-2.1.0[${PYTHON_USEDEP}]
	>=dev-python/pooch-1.7[${PYTHON_USEDEP}]
	>=dev-python/scikit-learn-1.6.0[${PYTHON_USEDEP}]
	>=dev-python/scipy-1.15.0[${PYTHON_USEDEP}]
	>=dev-python/soundfile-0.12.1[${PYTHON_USEDEP}]
	>=dev-python/soxr-1.0.0[${PYTHON_USEDEP}]
"
