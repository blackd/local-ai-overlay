# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Python bindings to Kaldi's OpenFST operations; wetext's engine, so the
# dependency of VoxCPM's text normaliser. setup.py drives cmake, which
# FetchContents two tarballs — a pinned csukuangfj OpenFST fork (built
# static into the module; the tree has no openfst) and pybind11 — and
# looks for pre-placed copies in the source dir first: both arrive via
# SRC_URI under the exact names it checks, so the build stays offline.
#
# USE=doc installs upstream's own HTML build, the gh-pages deploy of
# the release commit: the docs need k2 and torch to generate their
# figures, neither is packaged, and the GitHub release named "doc" is
# republished on every push to master, so only the deploy commit is a
# stable artifact.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_EXT=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

OPENFST_TAG="1.8.5-2026-07-09"
PYBIND11_PV="3.0.0"
# gh-pages commit "deploy: 3bd58c1b", the v1.9.0 release commit.
DOC_COMMIT="1d39f1d07bafb66f061ba2a39bc5dfcff2bc96a2"

DESCRIPTION="Python wrapper for OpenFST and its extensions from Kaldi"
HOMEPAGE="https://github.com/k2-fsa/kaldifst"
SRC_URI+="
	https://github.com/csukuangfj/openfst/archive/refs/tags/v${OPENFST_TAG}.tar.gz
		-> openfst-${OPENFST_TAG}.tar.gz
	https://github.com/pybind/pybind11/archive/refs/tags/v${PYBIND11_PV}.tar.gz
		-> pybind11-${PYBIND11_PV}.tar.gz
	doc? ( https://github.com/k2-fsa/kaldifst/archive/${DOC_COMMIT}.tar.gz -> ${P}-html.gh.tar.gz )
"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="doc"

# Tests pull googletest at configure time.
RESTRICT="test"

BDEPEND="dev-build/cmake"

src_unpack() {
	# Only the sdist; the two cmake inputs are consumed as tarballs.
	unpack "${P}.tar.gz"
	use doc && unpack "${P}-html.gh.tar.gz"
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

python_install_all() {
	if use doc; then
		# _sources holds the reST inputs Sphinx copies for its "show
		# source" links, no use installed.
		rm -r "${WORKDIR}/kaldifst-${DOC_COMMIT}"/{_sources,.buildinfo,.nojekyll} || die
		local HTML_DOCS=( "${WORKDIR}/kaldifst-${DOC_COMMIT}/." )
	fi
	distutils-r1_python_install_all
}
