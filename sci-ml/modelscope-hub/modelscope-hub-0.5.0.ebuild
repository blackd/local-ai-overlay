# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# ModelScope Hub client, the download/upload layer behind the modelscope
# umbrella package and the engines that fetch weights from
# modelscope.cn. Installs the modelscope, ms, modelscope-hub and ms-hub
# console scripts; upstream keeps all four here so the umbrella
# package never owns a script path.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="The official Python client to connect with ModelScope Hub"
HOMEPAGE="https://github.com/modelscope/modelscope https://pypi.org/project/modelscope-hub/"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=dev-python/cryptography-41[${PYTHON_USEDEP}]
	>=dev-python/filelock-3.9[${PYTHON_USEDEP}]
	>=dev-python/requests-2.28[${PYTHON_USEDEP}]
	>=dev-python/tqdm-4.64.0[${PYTHON_USEDEP}]
	>=dev-python/urllib3-1.26[${PYTHON_USEDEP}]
"
BDEPEND="
	test? (
		dev-python/responses[${PYTHON_USEDEP}]
	)
"

distutils_enable_tests pytest

python_test() {
	# "remote" tests talk to the live hub with credentials from a .env.
	epytest -m "not remote"
}
