# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Numbers to words in some fifty languages. Pulled in by several
# text-to-speech engines for number normalisation. The library itself
# imports only the standard library; docopt serves the num2words
# command-line script installed next to it.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Modules to convert numbers to words. Easily extensible"
HOMEPAGE="https://github.com/savoirfairelinux/num2words https://pypi.org/project/num2words/"

LICENSE="LGPL-2.1+"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="dev-python/docopt[${PYTHON_USEDEP}]"

distutils_enable_tests pytest

# Drives the installed script through delegator.py, which is not packaged.
EPYTEST_IGNORE=( tests/test_cli.py )
