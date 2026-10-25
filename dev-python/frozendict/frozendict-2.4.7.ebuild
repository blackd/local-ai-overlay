# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Immutable dict, a dependency of einx. Built pure-python on purpose:
# the sdist's C extension only carries sources for CPython 3.6 to 3.10
# and setup.py marks it optional, so without FROZENDICT_PURE_PY=1 the
# build would depend on a failed compile falling back. PyPI ships
# py3-none-any only for 3.12 and later, so this matches upstream.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="A simple immutable dictionary"
HOMEPAGE="https://github.com/Marco-Sulla/python-frozendict https://pypi.org/project/frozendict/"

LICENSE="LGPL-3"
SLOT="0"
KEYWORDS="~amd64"

export FROZENDICT_PURE_PY=1

distutils_enable_tests pytest
