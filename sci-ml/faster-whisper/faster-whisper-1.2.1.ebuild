# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Whisper speech recognition on the CTranslate2 engine, the library
# behind LocalAI's faster-whisper backend and whisperx. Built from the
# GitHub tag: PyPI has no sdist. The vad_filter option needs
# onnxruntime, which no repository here provides; the import is lazy
# and fails with a clear RuntimeError, everything else works without
# it. The Silero VAD model ships inside the package as data. numpy is
# imported at module level but missing from upstream's requirements.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

DESCRIPTION="Faster Whisper transcription with CTranslate2"
HOMEPAGE="https://github.com/SYSTRAN/faster-whisper https://pypi.org/project/faster-whisper/"
SRC_URI="https://github.com/SYSTRAN/faster-whisper/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
# The tests download Whisper models from the Hub.
RESTRICT="test"

RDEPEND="
	sci-ml/huggingface_hub[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		>=dev-python/av-11[${PYTHON_USEDEP}]
		>=dev-python/ctranslate2-4.0[${PYTHON_USEDEP}]
		<dev-python/ctranslate2-5[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/tqdm[${PYTHON_USEDEP}]
		<sci-ml/tokenizers-1[${PYTHON_USEDEP}]
	')
"
