# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# python-soxr, librosa's resampler. Builds the nanobind extension
# against the SYSTEM libsoxr (upstream vendors a libsoxr fork as a
# submodule; the sdist's CMake exposes a system toggle). Version
# tracks the fish-speech resolution snapshot.

EAPI=8

DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=scikit-build-core
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

DESCRIPTION="High-quality, fast sample rate conversion for Python (libsoxr binding)"
HOMEPAGE="https://github.com/dofuuz/python-soxr https://pypi.org/project/soxr/"
SRC_URI="https://files.pythonhosted.org/packages/source/s/soxr/${P}.tar.gz"

LICENSE="LGPL-2.1+"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="media-libs/soxr:="
RDEPEND="${DEPEND}
	$(python_gen_cond_dep 'dev-python/numpy[${PYTHON_USEDEP}]')
"
BDEPEND="
	virtual/pkgconfig
	$(python_gen_cond_dep 'dev-python/nanobind[${PYTHON_USEDEP}]')
"

src_configure() {
	# Verify the option name against the sdist's CMakeLists at bumps.
	DISTUTILS_ARGS=(
		-DUSE_SYSTEM_LIBSOXR=ON
	)
	distutils-r1_src_configure
}
