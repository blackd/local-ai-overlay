# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# The PyTorch Lightning trainer together with Lightning Fabric: the
# sdist carries both source trees and setup.py installs them as one
# distribution, pytorch_lightning plus lightning_fabric, exactly as
# the PyPI wheel. Dependency of sci-ml/lightning and ACE-Step. The
# requirement files' upper bounds are CI pins that setup.py drops at
# build time. aiohttp is fsspec's "http" extra, which the tree's
# fsspec has no flag for.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="PyTorch Lightning is the lightweight PyTorch wrapper for ML researchers"
HOMEPAGE="https://github.com/Lightning-AI/pytorch-lightning https://pypi.org/project/pytorch-lightning/"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
# No test-suite in the sdist.
RESTRICT="test"

RDEPEND="
	>=sci-ml/pytorch-2.1.0[${PYTHON_SINGLE_USEDEP}]
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
