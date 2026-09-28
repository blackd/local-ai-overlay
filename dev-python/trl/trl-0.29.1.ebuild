# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Transformer Reinforcement Learning: SFT and the preference trainers
# (DPO, KTO, ORPO, ...). Packaged for sci-ml/soup-cli; every dependency
# is a tree package.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

DESCRIPTION="Train transformer language models with reinforcement learning"
HOMEPAGE="https://github.com/huggingface/trl"
SRC_URI="https://github.com/huggingface/${PN}/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.gh.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
# The suite needs GPUs, network access and peft/vllm extras.
RESTRICT="test"

RDEPEND="
	sci-ml/accelerate[${PYTHON_SINGLE_USEDEP}]
	sci-ml/datasets[${PYTHON_SINGLE_USEDEP}]
	sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]
	sci-ml/transformers[${PYTHON_SINGLE_USEDEP}]
"
DEPEND="${RDEPEND}"
