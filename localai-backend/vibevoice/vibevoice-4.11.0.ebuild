# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI realtime TTS/ASR backend (Microsoft VibeVoice). Upstream's
# install clones VibeVoice from UNPINNED git main at install time; we
# pin the commit below (upstream has no tags) and install the pure-
# python package next to backend.py. The venv skeleton lives in
# local-ai-python.eclass; wheels carry only librosa (fish-speech's
# pin, its closure is tree packages) and diffusers 0.40.0 (same pin
# and huggingface-hub reasoning as localai-backend/transformers).
# Deliberately NOT shipped from upstream's requirements/pyproject:
# gradio, av, aiortc, fastapi, uvicorn, pydub, requests,
# ml-collections, absl-py — demo- and vllm-plugin-only, nothing the
# imported vibevoice subset or backend.py touches — and apex
# (try/except-guarded NVIDIA-only fused kernels).

EAPI=8

# backend.py imports these at module level — the real inference
# closure for both the streaming-TTS and ASR paths.
LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend
	vibevoice.modular.modeling_vibevoice_streaming_inference
	vibevoice.processor.vibevoice_streaming_processor
	vibevoice.modular.modeling_vibevoice_asr
	vibevoice.processor.vibevoice_asr_processor"

inherit local-ai-python

VIBEVOICE_COMMIT="16fb2cb1217c9934a886e1948ffb06120caa2df5"

DESCRIPTION="LocalAI realtime TTS/ASR backend (Microsoft VibeVoice gRPC server)"
SRC_URI+="
	https://github.com/microsoft/VibeVoice/archive/${VIBEVOICE_COMMIT}.tar.gz
		-> vibevoice-${VIBEVOICE_COMMIT}.gh.tar.gz
"
VV_S="${WORKDIR}/VibeVoice-${VIBEVOICE_COMMIT}"

LICENSE="MIT"

RDEPEND+="
	sci-ml/transformers[${PYTHON_SINGLE_USEDEP}]
	sci-ml/accelerate[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/decorator[${PYTHON_USEDEP}]
		dev-python/joblib[${PYTHON_USEDEP}]
		dev-python/lazy-loader[${PYTHON_USEDEP}]
		dev-python/llvmlite[${PYTHON_USEDEP}]
		dev-python/msgpack[${PYTHON_USEDEP}]
		dev-python/numba[${PYTHON_USEDEP}]
		dev-python/pooch[${PYTHON_USEDEP}]
		dev-python/scikit-learn[${PYTHON_USEDEP}]
		dev-python/scipy[${PYTHON_USEDEP}]
		dev-python/soundfile[${PYTHON_USEDEP}]
		dev-python/soxr[${PYTHON_USEDEP}]
		dev-python/tqdm[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"

src_unpack() {
	local-ai-python_src_unpack
	unpack "vibevoice-${VIBEVOICE_COMMIT}.gh.tar.gz"
}

src_install() {
	exeinto "${BACKEND_DIR}"
	doexe backend.py

	# The pinned VibeVoice package, importable next to backend.py —
	# pure python plus two bundled json configs.
	insinto "${BACKEND_DIR}"
	doins -r "${VV_S}/vibevoice"

	local-ai-python_install_venv
	python_optimize "${ED}${BACKEND_DIR}/vibevoice"
	local-ai-python_install_meta
	local-ai-python_smoke_test
}
