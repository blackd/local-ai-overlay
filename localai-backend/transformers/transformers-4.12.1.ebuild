# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI generic HuggingFace backend: text generation, embeddings and
# assorted pipelines through the transformers library, plus
# SentenceTransformer embedding models. The venv skeleton lives in
# local-ai-python.eclass; the wheels tarball carries only
# sentence-transformers and diffusers (noise schedulers for
# VibeVoice-style configs) — everything else is tree packages via
# system-site, including sci-ml/bitsandbytes for 4/8-bit quantized
# loading. diffusers is pinned to 0.40.0: 0.41 raised its
# huggingface-hub floor to 1.32, past the tree's 1.26; 0.40 accepts
# >=1.23.
# Deliberately NOT shipped: llvmlite/numba (upstream's requirements
# list them for audio feature extractors nothing in backend.py or the
# shipped libraries imports) and the Intel/OpenVINO stack (lazily
# imported for request types this packaging never serves).

EAPI=8

LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend transformers sentence_transformers diffusers bitsandbytes scipy"

inherit local-ai-python

DESCRIPTION="LocalAI generic HuggingFace transformers backend (gRPC server)"

LICENSE="MIT Apache-2.0"

RDEPEND+="
	sci-ml/transformers[${PYTHON_SINGLE_USEDEP}]
	sci-ml/accelerate[${PYTHON_SINGLE_USEDEP}]
	sci-ml/bitsandbytes[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/scipy[${PYTHON_USEDEP}]
		dev-python/scikit-learn[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/soundfile[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"
