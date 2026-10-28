# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# ctypes bindings to llama.cpp, used by neutts and outetts for their
# text models. The sdist vendors the llama.cpp tree the bindings were
# generated against (ggml 0.25.3); the ctypes layer mirrors that exact
# C API, so it is built here rather than pointed at the LocalAI
# backend's libllama, which follows LocalAI's own pin. scikit-build
# installs libllama and the libggml* set under llama_cpp/lib with an
# $ORIGIN RUNPATH, where llama_cpp.py dlopen's them. Same CPU kernel
# gates and Vulkan surface as local-ai-ggml.eclass; cuda/rocm are not
# wired. LLAVA_BUILD keeps upstream's default: libmtmd, the multimodal
# library behind the vision chat handlers, is built alongside libllama.

EAPI=8

DISTUTILS_USE_PEP517=scikit-build-core
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi toolchain-funcs

DESCRIPTION="Python bindings for the llama.cpp library"
HOMEPAGE="https://github.com/abetlen/llama-cpp-python https://pypi.org/project/llama-cpp-python/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
_cpu_flags=( amx_bf16 amx_int8 amx_tile avx avx_vnni avx2 avx512_bf16 avx512bw avx512f avx512vbmi avx512_vnni bmi2 fma3 f16c sse4_2 )
IUSE="native openblas +openmp vulkan video_cards_amdgpu ${_cpu_flags[*]/#/cpu_flags_x86_}"
unset _cpu_flags
# The suite needs the server extras and downloads models from the Hub.
RESTRICT="test"

RDEPEND="
	$(python_gen_cond_dep '
		>=dev-python/diskcache-5.6.1[${PYTHON_USEDEP}]
		>=dev-python/jinja2-2.11.3[${PYTHON_USEDEP}]
		>=dev-python/numpy-1.20.0[${PYTHON_USEDEP}]
		>=dev-python/typing-extensions-4.5.0[${PYTHON_USEDEP}]
	')
	openblas? ( sci-libs/openblas )
	vulkan? (
		media-libs/vulkan-loader
		video_cards_amdgpu? ( media-libs/mesa[vulkan,video_cards_radeonsi] )
	)
"
DEPEND="${RDEPEND}
	vulkan? ( dev-util/vulkan-headers )
"
BDEPEND="
	vulkan? ( media-libs/shaderc )
"

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
	python-single-r1_pkg_setup
}

python_configure_all() {
	DISTUTILS_ARGS=(
		-DLLAMA_BUILD=ON
		-DLLAVA_BUILD=ON
		-DGGML_CCACHE=OFF
		-DGGML_NATIVE=$(usex native)
		-DGGML_BLAS=$(usex openblas)
		-DGGML_BLAS_VENDOR=OpenBLAS
		-DGGML_OPENMP=$(usex openmp)
		-DGGML_VULKAN=$(usex vulkan)
		-DGGML_AMX_BF16=$(usex cpu_flags_x86_amx_bf16)
		-DGGML_AMX_INT8=$(usex cpu_flags_x86_amx_int8)
		-DGGML_AMX_TILE=$(usex cpu_flags_x86_amx_tile)
		-DGGML_AVX=$(usex cpu_flags_x86_avx)
		-DGGML_AVX_VNNI=$(usex cpu_flags_x86_avx_vnni)
		-DGGML_AVX2=$(usex cpu_flags_x86_avx2)
		-DGGML_AVX512_BF16=$(usex cpu_flags_x86_avx512_bf16)
		-DGGML_AVX512_VBMI=$(usex cpu_flags_x86_avx512vbmi)
		-DGGML_AVX512_VNNI=$(usex cpu_flags_x86_avx512_vnni)
		-DGGML_BMI2=$(usex cpu_flags_x86_bmi2)
		-DGGML_F16C=$(usex cpu_flags_x86_f16c)
		-DGGML_FMA=$(usex cpu_flags_x86_fma3)
		-DGGML_SSE42=$(usex cpu_flags_x86_sse4_2)
	)
	# The base AVX-512 kernels serve both the f and bw subsets.
	if use cpu_flags_x86_avx512f || use cpu_flags_x86_avx512bw; then
		DISTUTILS_ARGS+=( -DGGML_AVX512=ON )
	else
		DISTUTILS_ARGS+=( -DGGML_AVX512=OFF )
	fi
}
