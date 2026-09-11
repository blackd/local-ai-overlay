# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# JIT compiler for numeric python; resampy's engine. Paired with
# =dev-python/llvmlite-0.49* (numba releases pin one llvmlite minor;
# re-derive the pair at bumps from numba's setup.py). Version tracks
# the fish-speech resolution snapshot.

EAPI=8

DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

DESCRIPTION="NumPy-aware optimizing compiler for Python"
HOMEPAGE="https://numba.pydata.org/ https://pypi.org/project/numba/"
SRC_URI="https://github.com/numba/numba/archive/refs/tags/${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="BSD-2"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	$(python_gen_cond_dep '
		=dev-python/llvmlite-0.49*[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"

# The suite is enormous and wants threading layers we don't gate yet.
RESTRICT="test"

python_compile() {
	export NUMBA_DISABLE_OPENMP=0
	distutils-r1_python_compile -j1
}
