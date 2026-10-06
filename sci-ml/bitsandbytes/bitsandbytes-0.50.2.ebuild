# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# k-bit quantization kernels for PyTorch: QLoRA 4/8-bit loading in
# transformers (the localai-backend/transformers venv) and soup-cli
# training. Upstream ships prebuilt CUDA-only wheels; this builds the
# native library from source through the CMake COMPUTE_BACKEND matrix.
# The python package always carries the CPU library and USE=rocm/cuda
# adds the GPU one beside it — the exact layout upstream wheels use;
# the loader picks at runtime by the torch build (the HIP library name
# embeds hipconfig's version, e.g. libbitsandbytes_rocm72.so).

EAPI=8

DISTUTILS_USE_PEP517=standalone
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 local-ai-rocm multiprocessing

DESCRIPTION="k-bit optimizers and quantization for PyTorch"
HOMEPAGE="https://github.com/bitsandbytes-foundation/bitsandbytes"
SRC_URI="https://github.com/bitsandbytes-foundation/bitsandbytes/archive/${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="cuda rocm"
REQUIRED_USE="?? ( cuda rocm ) rocm? ( ${ROCM_REQUIRED_USE} )"

RDEPEND="
	$(python_gen_cond_dep '
		sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/packaging[${PYTHON_USEDEP}]
	')
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	rocm? (
		>=dev-util/hip-${ROCM_VERSION}:=
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=
		>=sci-libs/hipRAND-${ROCM_VERSION}:=
		>=sci-libs/hipBLASLt-${ROCM_VERSION}:=
	)
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-build/cmake
	$(python_gen_cond_dep '
		dev-python/scikit-build-core[${PYTHON_USEDEP}]
		dev-python/setuptools[${PYTHON_USEDEP}]
		dev-python/trove-classifiers[${PYTHON_USEDEP}]
	')
"

src_configure() {
	# scikit-build-core reads CMAKE_ARGS: the pep517 wheel build runs ONE
	# CMake pass, so the wheel carries the primary (GPU when enabled)
	# library; the always-needed CPU library is a second plain CMake
	# build appended in python_install.
	local args=( -DCOMPUTE_BACKEND=cpu )
	if use rocm; then
		local amdgpu_flags=$(get_amdgpu_flags)
		args=(
			-DCOMPUTE_BACKEND=hip
			-DCMAKE_HIP_ARCHITECTURES="${amdgpu_flags%;}"
		)
	elif use cuda; then
		args=( -DCOMPUTE_BACKEND=cuda )
	fi
	export CMAKE_ARGS="${args[*]}"
	distutils-r1_src_configure
}

src_compile() {
	distutils-r1_src_compile

	if use rocm || use cuda; then
		# The loader falls back to libbitsandbytes_cpu.so whenever torch
		# reports no GPU; upstream wheels ship it unconditionally.
		cmake -S "${S}" -B "${WORKDIR}/cpu-build" -DCOMPUTE_BACKEND=cpu || die
		cmake --build "${WORKDIR}/cpu-build" -j "$(makeopts_jobs)" || die
	fi
}

python_install() {
	distutils-r1_python_install

	if use rocm || use cuda; then
		python_moduleinto bitsandbytes
		python_domodule "${WORKDIR}"/cpu-build/bitsandbytes/libbitsandbytes_cpu.so
	fi
}
