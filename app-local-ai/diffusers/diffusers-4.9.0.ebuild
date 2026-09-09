# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI image/video-generation backend (HuggingFace diffusers), the
# first python backend: a venv assembled OFFLINE in src_install from
# the wheels release asset, with --system-site-packages exposing every
# compiled dependency as a real Portage package — torch (ROCm and all)
# included. The venv layer is pure python only.
#
# The gRPC stubs (backend_pb2*.py) ship pre-generated inside the wheels
# tarball: the tree has no dev-python/grpcio-tools and the system grpc
# builds no python plugin. The gen script generates them from the
# digest-verified source tarball, so they match what compiles here.

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )

inherit local-ai-backend python-single-r1

DIFFUSERS_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/diffusers-v${PV}"

DESCRIPTION="LocalAI image and video generation backend (diffusers gRPC server)"
SRC_URI="
	${LOCAL_AI_SRC_URI}
	${DIFFUSERS_DISTFILES}/diffusers-${PV}-wheels.tar.xz
"
S="${WORKDIR}/LocalAI-${PV}/backend/python/diffusers"

LICENSE="MIT Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="${PYTHON_DEPS}
	sci-ml/local-ai
	$(python_gen_cond_dep '
		sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]
		sci-ml/torchvision[${PYTHON_SINGLE_USEDEP}]
		sci-ml/sentencepiece[${PYTHON_USEDEP}]
		media-libs/opencv[python,${PYTHON_USEDEP}]
		dev-python/av[${PYTHON_USEDEP}]
		dev-python/safetensors[${PYTHON_USEDEP}]
		dev-python/tokenizers[${PYTHON_USEDEP}]
		>=dev-python/grpcio-1.76.0[${PYTHON_USEDEP}]
		dev-python/protobuf[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/ftfy[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/regex[${PYTHON_USEDEP}]
		dev-python/filelock[${PYTHON_USEDEP}]
		dev-python/fsspec[${PYTHON_USEDEP}]
		dev-python/packaging[${PYTHON_USEDEP}]
		dev-python/psutil[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
		dev-python/tqdm[${PYTHON_USEDEP}]
	')
"

BACKEND_DIR="/usr/libexec/local-ai/backends/diffusers"

src_unpack() {
	unpack "local-ai-${PV}.tar.gz" "diffusers-${PV}-wheels.tar.xz"
}

src_compile() {
	# Nothing to build here: the Makefile in this directory drives
	# upstream's uv-based image install, which the venv assembled in
	# src_install replaces entirely.
	:
}

src_install() {
	exeinto "${BACKEND_DIR}"
	doexe backend.py diffusers_dynamic_loader.py \
		"${WORKDIR}"/stubs/backend_pb2.py "${WORKDIR}"/stubs/backend_pb2_grpc.py
	# The shared helpers backend.py imports from ../common.
	insinto "${BACKEND_DIR}/common"
	doins ../common/grpc_auth.py ../common/model_utils.py

	# The venv: system-site for every compiled package, wheels for the
	# pure-python layer, assembled fully offline.
	"${EPYTHON}" -m venv --system-site-packages "${ED}${BACKEND_DIR}/venv" || die
	"${ED}${BACKEND_DIR}/venv/bin/python" -m pip install \
		--no-index --find-links "${WORKDIR}/wheels" --no-deps --no-compile \
		"${WORKDIR}"/wheels/*.whl || die
	# The venv's paths must not remember the image root.
	find "${ED}${BACKEND_DIR}/venv/bin" -type f -exec sed -i "s:${D}::g" {} + || die
	python_optimize "${ED}${BACKEND_DIR}/venv/lib"

	local-ai-backend_install_meta diffusers
}

pkg_postinst() {
	elog "Device selection follows the model YAML: until the auto-detect"
	elog "patch lands upstream, set 'cuda: true' (ROCm torch reports as"
	elog "CUDA) on gallery models that lack it."
}
