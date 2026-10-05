# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI speaker-recognition backend (voice identification and
# embedding scoring): three runtime-selectable engines — SpeechBrain
# encoders, plain ONNX embedding models via onnxruntime, and a
# transformers audio-classification head. The venv skeleton lives in
# local-ai-python.eclass; the wheels tarball carries speechbrain,
# HyperPyYAML and a ruamel.yaml pinned below 0.19: HyperPyYAML caps
# ruamel.yaml<0.19.0 and the 0.19 series removed the API it uses, so
# the venv shadows the tree's 0.19 ruamel instead of relaxing the cap.

EAPI=8

LOCAL_AI_PYTHON_EXES="backend.py engines.py"
LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend engines speechbrain transformers onnxruntime"

inherit local-ai-python

DESCRIPTION="LocalAI speaker-recognition backend (gRPC server)"

LICENSE="MIT Apache-2.0"

RDEPEND+="
	sci-ml/transformers[${PYTHON_SINGLE_USEDEP}]
	sci-ml/torchaudio[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/soundfile[${PYTHON_USEDEP}]
		sci-libs/onnxruntime[python,${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"
