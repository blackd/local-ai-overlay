# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Metrics for torch (accuracy, WER, PESQ wrappers, ...), a dependency
# of pytorch-lightning and pyannote-audio. setup.py reads
# requirements/base.txt and drops the upper bounds itself, so the
# declared dependencies are the minimums only.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="PyTorch native Metrics"
HOMEPAGE="https://github.com/Lightning-AI/torchmetrics https://pypi.org/project/torchmetrics/"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
# No test-suite in the sdist.
RESTRICT="test"

RDEPEND="
	>=sci-ml/pytorch-2.0.0[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		>=dev-python/lightning-utilities-0.15.3[${PYTHON_USEDEP}]
		>dev-python/numpy-1.20.0[${PYTHON_USEDEP}]
		>dev-python/packaging-17.1[${PYTHON_USEDEP}]
		dev-python/typing-extensions[${PYTHON_USEDEP}]
	')
"
# setup.py parses the requirement files with packaging.
BDEPEND="$(python_gen_cond_dep 'dev-python/packaging[${PYTHON_USEDEP}]')"
