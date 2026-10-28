# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI speech-to-text backend on faster-whisper, Whisper models run
# through the CTranslate2 engine. backend.py imports torch (device
# choice) and faster_whisper only; the opencv/accelerate/compel/peft/
# optimum-quanto lines in upstream's CPU and CUDA requirement files are
# never imported and are not carried, matching upstream's own ROCm and
# Jetson profiles. The engine is sci-ml/faster-whisper, so this backend
# has no venv and no wheels tarball (local-ai-python.eclass,
# LOCAL_AI_PYTHON_NO_VENV). GPU support follows sci-libs/ctranslate2's
# rocm flag; upstream's ROCm profile fetches a prebuilt wheel instead.

EAPI=8

LOCAL_AI_PYTHON_NO_VENV=1

# backend.py's import closure plus the engine and the binding it loads
# the model through.
LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend
	faster_whisper
	ctranslate2"

inherit local-ai-python

DESCRIPTION="LocalAI speech-to-text backend (faster-whisper gRPC server)"

LICENSE="MIT"

RDEPEND+="
	sci-ml/faster-whisper[${PYTHON_SINGLE_USEDEP}]
"
DEPEND="${RDEPEND}"
