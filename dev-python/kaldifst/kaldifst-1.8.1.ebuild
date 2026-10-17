# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Python bindings to Kaldi's OpenFST operations; wetext's engine, so the
# dependency of VoxCPM's text normaliser. setup.py drives cmake, which
# FetchContents two tarballs — a pinned csukuangfj OpenFST fork (built
# static into the module; the tree has no openfst) and pybind11 — and
# looks for pre-placed copies in the source dir first: both arrive via
# SRC_URI under the exact names it checks, so the build stays offline.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_EXT=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

OPENFST_TAG="1.8.5-2026-04-10"
PYBIND11_PV="3.0.0"

DESCRIPTION="Python wrapper for OpenFST and its extensions from Kaldi"
HOMEPAGE="https://github.com/k2-fsa/kaldifst"
SRC_URI+="
	https://github.com/csukuangfj/openfst/archive/refs/tags/v${OPENFST_TAG}.tar.gz
		-> openfst-${OPENFST_TAG}.tar.gz
	https://github.com/pybind/pybind11/archive/refs/tags/v${PYBIND11_PV}.tar.gz
		-> pybind11-${PYBIND11_PV}.tar.gz
"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

# Tests pull googletest at configure time.
RESTRICT="test"

BDEPEND="dev-build/cmake"

src_unpack() {
	# Only the sdist; the two cmake inputs are consumed as tarballs.
	unpack "${P}.tar.gz"
}

src_prepare() {
	distutils-r1_src_prepare
	cp "${DISTDIR}/openfst-${OPENFST_TAG}.tar.gz" "${DISTDIR}/pybind11-${PYBIND11_PV}.tar.gz" "${S}/" || die
}

python_compile() {
	# KALDIFST_CMAKE_ARGS replaces setup.py's defaults, so restate the
	# build type; CFLAGS/CXXFLAGS/LDFLAGS reach cmake from the environment.
	local -x KALDIFST_CMAKE_ARGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE=ON"
	local -x KALDIFST_MAKE_ARGS="${MAKEOPTS}"
	distutils-r1_python_compile
}
