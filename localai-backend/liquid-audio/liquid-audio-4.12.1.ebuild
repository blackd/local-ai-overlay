# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI speech-to-speech backend (Liquid AI LFM2-Audio): audio in,
# text or audio out, plus the chat path with tools and the LoRA
# fine-tuning job. The engine is sci-ml/liquid-audio, a system library,
# so this backend has no venv and no wheels tarball: backend.py runs
# under the system interpreter (local-ai-python.eclass,
# LOCAL_AI_PYTHON_NO_VENV).

EAPI=8

LOCAL_AI_PYTHON_NO_VENV=1

# backend.py's import closure: the model/chat classes, the fine-tuning
# data loader and trainer it imports lazily on the first training job.
LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend
	liquid_audio
	liquid_audio.data.dataloader
	liquid_audio.trainer"

inherit local-ai-python

DESCRIPTION="LocalAI speech-to-speech backend (Liquid AI LFM2-Audio gRPC server)"

LICENSE="MIT"

# torchaudio for torchaudio.load/save, soundfile for backend.py's own
# read/write path; the rest of the closure is sci-ml/liquid-audio's.
RDEPEND+="
	sci-ml/liquid-audio[${PYTHON_SINGLE_USEDEP}]
	sci-ml/torchaudio[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/soundfile[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"
