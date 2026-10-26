# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# einops-style tensor notation that works over numpy, torch, jax and
# others. Each framework is imported lazily when one of its tensors
# shows up, so the hard dependencies are numpy, sympy (shape algebra)
# and frozendict only. The test-suite probes for installed frameworks
# the same way and runs for whatever it finds; numpy alone is enough.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Universal Notation for Tensor Operations in Python"
HOMEPAGE="https://github.com/fferflo/einx https://einx.readthedocs.io https://pypi.org/project/einx/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	dev-python/frozendict[${PYTHON_USEDEP}]
	dev-python/numpy[${PYTHON_USEDEP}]
	dev-python/sympy[${PYTHON_USEDEP}]
"

distutils_enable_tests pytest

src_prepare() {
	distutils-r1_src_prepare
	# Package discovery only excludes test_typechecking*; the test/
	# directory has an __init__.py and gets installed as a top-level
	# "test" package otherwise.
	sed -i 's/^exclude = \["test_typechecking\*"\]$/exclude = ["test*", "docs*"]/' pyproject.toml || die
	grep -q '"test\*"' pyproject.toml || die "package exclusion not applied"
}
