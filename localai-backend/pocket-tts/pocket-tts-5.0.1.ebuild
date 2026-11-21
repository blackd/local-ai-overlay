# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-to-speech backend on Kyutai's pocket-tts, with voice
# cloning from an audio prompt. backend.py imports torch, scipy and
# pocket_tts; the engine is sci-ml/pocket-tts, so this backend has no
# venv and no wheels tarball (local-ai-python.eclass,
# LOCAL_AI_PYTHON_NO_VENV). Models and voices come from the Hub at
# run time; the model repository is gated upstream.

EAPI=8

LOCAL_AI_PYTHON_NO_VENV=1

LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend pocket_tts"

inherit local-ai-python

DESCRIPTION="LocalAI text-to-speech backend (pocket-tts gRPC server)"

LICENSE="MIT"

RDEPEND+="
	sci-ml/pocket-tts[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/scipy[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"
