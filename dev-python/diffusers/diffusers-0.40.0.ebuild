# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# HuggingFace diffusion pipelines and schedulers. Packaged as a system
# library for the backends that import it (ace-step, chatterbox,
# longcat-video); every dependency is a tree package. 0.40 is the
# newest release whose huggingface-hub bound (<2) fits the tree's
# transformers, which refuses hub 2.x.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

DESCRIPTION="State-of-the-art diffusion models for image, video and audio generation"
HOMEPAGE="https://github.com/huggingface/diffusers"
SRC_URI="https://github.com/huggingface/${PN}/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.gh.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
# The suite downloads models and wants GPUs.
RESTRICT="test"

RDEPEND="
	sci-ml/accelerate[${PYTHON_SINGLE_USEDEP}]
	>=sci-ml/huggingface_hub-1.23.0[${PYTHON_SINGLE_USEDEP}]
	<sci-ml/huggingface_hub-2[${PYTHON_SINGLE_USEDEP}]
	sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/filelock[${PYTHON_USEDEP}]
		<dev-python/httpx-1[${PYTHON_USEDEP}]
		dev-python/importlib-metadata[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/regex[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
		>=sci-ml/safetensors-0.8.0[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"
