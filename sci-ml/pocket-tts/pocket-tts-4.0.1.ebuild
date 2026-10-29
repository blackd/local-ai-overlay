# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Kyutai's small text-to-speech model library, the engine behind
# localai-backend/pocket-tts. The wheel carries the pocket_tts package
# alone, as upstream's own build configuration has it; the sdist's
# training, evaluation and Rust port trees and their imports (sphn,
# jiwer, ...) are repository context, not installed code. pyyaml is
# imported at module level but undeclared. soundfile reads audio
# prompts for voice cloning, torchao serves the quantize option: both
# upstream extras, both lazy imports. Model weights and voices are
# fetched from the Hub at run time.

EAPI=8

DISTUTILS_USE_PEP517=hatchling
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Kyutai's pocket-sized text-to-speech"
HOMEPAGE="https://github.com/kyutai-labs/pocket-tts https://pypi.org/project/pocket-tts/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
# The tests generate speech with models downloaded from the Hub.
RESTRICT="test"

RDEPEND="
	>=sci-ml/huggingface_hub-0.13.0[${PYTHON_SINGLE_USEDEP}]
	>=sci-ml/pytorch-2.5.0[${PYTHON_SINGLE_USEDEP}]
	sci-ml/torchao[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		>=dev-python/einops-0.4.0[${PYTHON_USEDEP}]
		>=dev-python/fastapi-0.100[${PYTHON_USEDEP}]
		>=dev-python/numpy-2[${PYTHON_USEDEP}]
		>=dev-python/pydantic-2[${PYTHON_USEDEP}]
		>=dev-python/python-multipart-0.0.21[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		>=dev-python/requests-2.20.0[${PYTHON_USEDEP}]
		>=dev-python/scipy-1.5.0[${PYTHON_USEDEP}]
		>=dev-python/soundfile-0.12.0[${PYTHON_USEDEP}]
		>=dev-python/typer-0.10.0[${PYTHON_USEDEP}]
		>=dev-python/typing-extensions-4.10.0[${PYTHON_USEDEP}]
		>=dev-python/uvicorn-0.13.0[${PYTHON_USEDEP}]
		>=sci-ml/safetensors-0.4.0[${PYTHON_USEDEP}]
		>=sci-ml/sentencepiece-0.2.1[${PYTHON_USEDEP}]
		>=sci-ml/tokenizers-0.21[${PYTHON_USEDEP}]
	')
"
