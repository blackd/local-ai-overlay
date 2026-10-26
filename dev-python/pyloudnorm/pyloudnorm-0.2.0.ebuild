# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# ITU-R BS.1770-4 loudness measurement and normalisation on numpy
# arrays. Used by text-to-speech engines to level their output.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Implementation of ITU-R BS.1770-4 loudness algorithm in Python"
HOMEPAGE="https://github.com/csteinmetz1/pyloudnorm https://pypi.org/project/pyloudnorm/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
# The tests read the BS.1770 compliance wav files from tests/data,
# which the sdist does not ship.
RESTRICT="test"

RDEPEND="
	dev-python/numpy[${PYTHON_USEDEP}]
	dev-python/scipy[${PYTHON_USEDEP}]
"
