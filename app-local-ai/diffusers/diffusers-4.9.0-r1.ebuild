# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI image/video-generation backend (HuggingFace diffusers), the
# first python backend. The venv skeleton (offline wheels, system-site
# tree packages, run.sh, build-time import smoke test) lives in
# local-ai-python.eclass; this ebuild adds only the diffusers-specific
# dependencies.

EAPI=8

LOCAL_AI_PYTHON_EXES="backend.py diffusers_dynamic_loader.py"

inherit local-ai-python

DESCRIPTION="LocalAI image and video generation backend (diffusers gRPC server)"

LICENSE="MIT Apache-2.0"

RDEPEND+="
	$(python_gen_cond_dep '
		sci-ml/torchvision[${PYTHON_SINGLE_USEDEP}]
		sci-ml/sentencepiece[${PYTHON_USEDEP}]
		media-libs/opencv[python,${PYTHON_USEDEP}]
		dev-python/av[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/ftfy[${PYTHON_USEDEP}]
	')
	dev-build/ninja
"
DEPEND="${RDEPEND}"

pkg_postinst() {
	elog "Device selection follows the model YAML: until the auto-detect"
	elog "patch lands upstream, set 'cuda: true' (ROCm torch reports as"
	elog "CUDA) on gallery models that lack it."
}
