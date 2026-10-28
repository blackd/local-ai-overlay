# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# The "lightning" namespace package: lightning.pytorch, lightning.fabric
# and lightning.data, the import path nemo-toolkit and pyannote-audio
# use. Its sdist carries one source tree and setup.py installs that
# one; the pytorch_lightning distribution is a runtime dependency as
# upstream declares it. Upper bounds in the requirement files are CI
# pins dropped at build time; aiohttp is fsspec's "http" extra.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="The Deep Learning framework to train, deploy, and ship AI products Lightning fast"
HOMEPAGE="https://github.com/Lightning-AI/pytorch-lightning https://pypi.org/project/lightning/"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
# No test-suite in the sdist.
RESTRICT="test"

RDEPEND="
	>=sci-ml/pytorch-2.1.0[${PYTHON_SINGLE_USEDEP}]
	sci-ml/pytorch-lightning[${PYTHON_SINGLE_USEDEP}]
	>sci-ml/torchmetrics-0.7.0[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/aiohttp[${PYTHON_USEDEP}]
		>=dev-python/fsspec-2022.5.0[${PYTHON_USEDEP}]
		>=dev-python/lightning-utilities-0.10.0[${PYTHON_USEDEP}]
		>=dev-python/packaging-23.0[${PYTHON_USEDEP}]
		>dev-python/pyyaml-5.4[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
		>=dev-python/tqdm-4.57.0[${PYTHON_USEDEP}]
		>dev-python/typing-extensions-4.5.0[${PYTHON_USEDEP}]
	')
"
# setup.py and .actions/assistant.py parse the requirement files.
BDEPEND="$(python_gen_cond_dep 'dev-python/packaging[${PYTHON_USEDEP}]')"
