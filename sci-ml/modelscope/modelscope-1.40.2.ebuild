# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# ModelScope umbrella package: pipelines, datasets, models and
# trainers on top of sci-ml/modelscope-hub, which since 1.40 owns the
# hub client and every console script. Upstream's hard dependencies
# are the hub set only; the "framework" extra is added here
# unconditionally because modelscope.pipelines, which the engines
# calling into ModelScope use (voxcpm's denoiser, funasr), imports it.
# The cv/nlp/audio/science extras are not covered. modelscope/ops
# carries CUDA/C++ torch extensions that are JIT-compiled at first use
# by the few models needing them, nothing is built here.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="ModelScope: bring the notion of Model-as-a-Service to life"
HOMEPAGE="https://github.com/modelscope/modelscope https://pypi.org/project/modelscope/"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
# No test-suite in the sdist.
RESTRICT="test"

# Hub set (requirements/hub.txt), then the framework extra.
RDEPEND="
	sci-ml/datasets[${PYTHON_SINGLE_USEDEP}]
	sci-ml/transformers[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		>=sci-ml/modelscope-hub-0.4.6[${PYTHON_USEDEP}]
		dev-python/filelock[${PYTHON_USEDEP}]
		dev-python/packaging[${PYTHON_USEDEP}]
		>=dev-python/requests-2.25[${PYTHON_USEDEP}]
		dev-python/setuptools[${PYTHON_USEDEP}]
		>=dev-python/tqdm-4.64.0[${PYTHON_USEDEP}]
		>=dev-python/urllib3-1.26[${PYTHON_USEDEP}]
		dev-python/addict[${PYTHON_USEDEP}]
		dev-python/attrs[${PYTHON_USEDEP}]
		dev-python/einops[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		>=dev-python/python-dateutil-2.1[${PYTHON_USEDEP}]
		>=dev-python/pyyaml-5.4[${PYTHON_USEDEP}]
		dev-python/scipy[${PYTHON_USEDEP}]
		>=dev-python/simplejson-3.3.0[${PYTHON_USEDEP}]
		>=dev-python/sortedcontainers-1.5.9[${PYTHON_USEDEP}]
	')
"
