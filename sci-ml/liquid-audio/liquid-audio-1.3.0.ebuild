# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Liquid AI's LFM2-Audio library: speech-to-speech model, chat state
# and the LoRA fine-tuning loop. Packaged as a system library for
# localai-backend/liquid-audio, the first python backend without a
# venv (local-ai-python.eclass, LOCAL_AI_PYTHON_NO_VENV); every
# dependency is a tree package. The "demo" extra (fastrtc) is the
# browser demo under liquid_audio.demo and is not pulled in; the
# backend never imports it.

EAPI=8

DISTUTILS_USE_PEP517=uv-build
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Liquid Audio - Speech-to-Speech audio models (LFM2-Audio)"
HOMEPAGE="https://www.liquid.ai/ https://github.com/Liquid4All/liquid-audio"

# LFM-Open-License-1.0: Apache-2.0 terms with a commercial-use cap
# (section 5), see licenses/ in this repository. MIT: the vendored
# liquid_audio.moshi subpackage (Kyutai Moshi, adapted from Meta's
# Audiocraft).
LICENSE="LFM-Open-License-1.0 MIT"
SLOT="0"
KEYWORDS="~amd64"
# The sdist ships no test-suite.
RESTRICT="test"

# huggingface_hub, safetensors and numpy are imported at module level
# (utils.py, moshi/models/loaders.py, moshi/modules/seanet.py) but
# missing from the sdist's dependency list.
RDEPEND="
	>=sci-ml/accelerate-1.10.1[${PYTHON_SINGLE_USEDEP}]
	>=sci-ml/datasets-4.8.4[${PYTHON_SINGLE_USEDEP}]
	sci-ml/huggingface_hub[${PYTHON_SINGLE_USEDEP}]
	>=sci-ml/pytorch-2.8.0[${PYTHON_SINGLE_USEDEP}]
	>=sci-ml/torchaudio-2.8.0[${PYTHON_SINGLE_USEDEP}]
	>=sci-ml/transformers-4.55.4[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		>=dev-python/einops-0.8.1[${PYTHON_USEDEP}]
		>=dev-python/librosa-0.11.0[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		sci-ml/safetensors[${PYTHON_USEDEP}]
		>=sci-ml/sentencepiece-0.2.1[${PYTHON_USEDEP}]
	')
"
