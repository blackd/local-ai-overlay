# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Shared helpers of the Lightning organisation: import guards, module
# availability checks, requirement parsing, apply_to_collection and
# friends. Dependency of torchmetrics and pytorch-lightning. Pure
# python on top of packaging and typing-extensions; the docs helpers'
# requests import is lazy and belongs to the "docs" extra.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Lightning toolbox for across the our ecosystem"
HOMEPAGE="https://github.com/Lightning-AI/utilities https://pypi.org/project/lightning-utilities/"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
# No test-suite in the sdist.
RESTRICT="test"

RDEPEND="
	>=dev-python/packaging-22[${PYTHON_USEDEP}]
	dev-python/typing-extensions[${PYTHON_USEDEP}]
"
# setup.py imports packaging to parse its own requirement files.
BDEPEND="dev-python/packaging[${PYTHON_USEDEP}]"
