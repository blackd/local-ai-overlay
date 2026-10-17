# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-to-speech backend (OpenBMB VoxCPM): tokenizer-free TTS
# with voice cloning. The venv skeleton lives in local-ai-python.eclass;
# wheels carry voxcpm itself (pure python, built from its sdist) and
# modelscope + modelscope-hub: VoxCPM.from_pretrained() defaults to
# load_denoiser=True and backend.py calls it with the model path only,
# so every load builds modelscope's ZipEnhancer pipeline whether or not
# the denoise option is on. Its weights are installed here (see below)
# instead of being fetched at load time. librosa and einops are overlay
# packages (dev-python/*), shared with the other python backends.
# Deliberately NOT shipped from upstream's requirements: gradio, spaces,
# funasr (app/demo only); datasets, argbind, matplotlib, tensorboardX
# (training); simplejson, sortedcontainers, addict (declared, never
# imported); triton (optional fast path, falls back to eager). The text
# normaliser behind the "normalize: true" option (wetext, contractions,
# textsearch) rides as wheels; its compiled engines are the overlay's
# dev-python/kaldifst and dev-python/pyahocorasick.

EAPI=8

# The ZipEnhancer denoiser VoxCPM.from_pretrained() loads by default:
# two files, pinned to their ModelScope revision, installed next to the
# backend so no model is fetched at load time (modelscope uses an
# existing directory as-is). The onnx file in that repo is a different
# runtime and is not needed.
ZIPENHANCER_REV="bed374bb53e4a5ffc62093676bab408a56b0db48"
ZIPENHANCER_URI="https://modelscope.cn/models/iic/speech_zipenhancer_ans_multiloss_16k_base/resolve/${ZIPENHANCER_REV}"

# backend.py's import closure plus the two lazy paths a load triggers:
# the v2 model module and the modelscope denoiser pipeline.
LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend
	voxcpm
	voxcpm.model.voxcpm2
	voxcpm.utils.text_normalize
	modelscope.pipelines
	modelscope.utils.constant"

inherit local-ai-python

DESCRIPTION="LocalAI text-to-speech backend (OpenBMB VoxCPM gRPC server)"
SRC_URI+="
	${ZIPENHANCER_URI}/pytorch_model.bin -> zipenhancer-ans-16k-base-${ZIPENHANCER_REV:0:12}.bin
	${ZIPENHANCER_URI}/configuration.json -> zipenhancer-ans-16k-base-${ZIPENHANCER_REV:0:12}.json
"

# Apache-2.0: the ZipEnhancer weights.
LICENSE="MIT Apache-2.0"

# transformers: LlamaTokenizerFast only. torchaudio (overlay) carries
# torchcodec for torchaudio.load. modelscope.pipelines imports its
# msdatasets layer, hence datasets (the tree's 5.x imports fine; the
# denoiser never uses it), addict (vendored from guru), pillow and
# simplejson; cryptography is modelscope-hub's. soundfile is backend.py's
# own; anyascii is textsearch's, kaldifst and pyahocorasick are
# wetext's/contractions' compiled engines. Wheels install --no-deps, so
# the rest of voxcpm's closure must be named here.
RDEPEND+="
	sci-ml/transformers[${PYTHON_SINGLE_USEDEP}]
	sci-ml/torchaudio[${PYTHON_SINGLE_USEDEP}]
	sci-ml/datasets[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/addict[${PYTHON_USEDEP}]
		dev-python/anyascii[${PYTHON_USEDEP}]
		dev-python/cryptography[${PYTHON_USEDEP}]
		dev-python/einops[${PYTHON_USEDEP}]
		dev-python/inflect[${PYTHON_USEDEP}]
		dev-python/kaldifst[${PYTHON_USEDEP}]
		dev-python/librosa[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/pyahocorasick[${PYTHON_USEDEP}]
		dev-python/pydantic[${PYTHON_USEDEP}]
		dev-python/regex[${PYTHON_USEDEP}]
		dev-python/simplejson[${PYTHON_USEDEP}]
		dev-python/soundfile[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"

src_install() {
	exeinto "${BACKEND_DIR}"
	doexe backend.py

	# The denoiser, under the file names modelscope's pipeline expects.
	insinto "${BACKEND_DIR}/zipenhancer"
	newins "${DISTDIR}/zipenhancer-ans-16k-base-${ZIPENHANCER_REV:0:12}.bin" pytorch_model.bin
	newins "${DISTDIR}/zipenhancer-ans-16k-base-${ZIPENHANCER_REV:0:12}.json" configuration.json

	local-ai-python_install_venv

	local site f
	for site in "${ED}${BACKEND_DIR}"/venv/lib/*/site-packages/voxcpm; do
		[[ -d ${site} ]] || die "voxcpm not found in the venv"

		# Point voxcpm's default denoiser id (core.py x2, zipenhancer.py)
		# at the installed copy; backend.py passes only the model path,
		# so the default is what gets loaded.
		for f in core.py zipenhancer.py; do
			sed -i "s|\"iic/speech_zipenhancer_ans_multiloss_16k_base\"|\"${EPREFIX}${BACKEND_DIR}/zipenhancer\"|g" "${site}/${f}" || die
			grep -q "${BACKEND_DIR}/zipenhancer" "${site}/${f}" || die "denoiser path sed did not apply to ${f}"
		done

		# Upstream's install.sh post-install edit (OpenBMB/VoxCPM#71): the
		# attention step feeds scaled_dot_product_attention tensors one
		# dimension short on some torch versions. Same sed, same scope.
		f="${site}/modules/minicpm4/model.py"
		[[ -e ${f} ]] || die "voxcpm minicpm4/model.py not found in the venv"
		sed -i 's/query_states = query_states\.contiguous()/query_states = query_states.unsqueeze(0)/g; s/key_cache = key_cache\.contiguous()/key_cache = key_cache.unsqueeze(0)/g; s/value_cache = value_cache\.contiguous()/value_cache = value_cache.unsqueeze(0)/g' "${f}" || die
		grep -q 'value_cache.unsqueeze(0)' "${f}" || die "minicpm4 attention sed did not apply"

		python_optimize "${site}"
	done

	local-ai-python_install_meta
	local-ai-python_smoke_test
}
