# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# pybind11 binding to sci-libs/ctranslate2, the module faster-whisper
# and whisperx import. Built from the python/ directory of the same
# GitHub tarball against the installed library of the same version.
# setup.py hard-codes an rpath into /usr/local for the wheel; dropped,
# the library is in the default search path here.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

DESCRIPTION="Python binding to the CTranslate2 inference engine"
HOMEPAGE="https://opennmt.net/CTranslate2 https://github.com/OpenNMT/CTranslate2 https://pypi.org/project/ctranslate2/"
SRC_URI="https://github.com/OpenNMT/CTranslate2/archive/refs/tags/v${PV}.tar.gz -> CTranslate2-${PV}.gh.tar.gz"
S="${WORKDIR}/CTranslate2-${PV}/python"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
# The tests download models and need torch, transformers and the
# upstream training frameworks.
RESTRICT="test"

RDEPEND="
	~sci-libs/ctranslate2-${PV}
	dev-python/numpy[${PYTHON_USEDEP}]
	<dev-python/pyyaml-7[${PYTHON_USEDEP}]
"
DEPEND="${RDEPEND}"
BDEPEND="dev-python/pybind11[${PYTHON_USEDEP}]"

src_prepare() {
	distutils-r1_src_prepare
	sed -i '/ldflags.append("-Wl,-rpath,\/usr\/local\/lib64:\/usr\/local\/lib")/d' setup.py || die
	grep -q 'rpath,/usr/local/lib64' setup.py && die "rpath flag still in setup.py"
}
