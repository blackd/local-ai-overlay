# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI tinygrad backend: text generation from GGUF weights, Whisper
# transcription and Stable Diffusion 1.x, all on tinygrad's own runtime
# with no torch. The engine is sci-ml/tinygrad, so no venv and no
# wheels tarball (LOCAL_AI_PYTHON_NO_VENV); torch is left out of the
# baseline (LOCAL_AI_PYTHON_NO_TORCH). vendor/ carries upstream's
# tinygrad ports of the Whisper, Stable Diffusion, CLIP and UNet models
# and tool_parsers/ the tool-call parsers, both imported relative to
# backend.py, so both are installed next to it.
#
# tinygrad compiles kernels at run time: through libLLVM on the CPU
# device, through comgr and the HIP runtime on AMD, through nvrtc on
# CUDA. The device is chosen through the environment (DEV=...) and
# tinygrad locates its libraries by listing /usr/lib64 and friends, so
# run.sh names the device per USE flag and points tinygrad at Gentoo's
# slotted libLLVM and at the lib64 ROCm libraries.
#
# backend.py loads GGUF models through tinygrad.apps.llm and the
# vendored UNet uses device.is_dtype_supported; both left tinygrad in
# 0.13, which replaced the LLM code with a rewritten tinygrad.llm.model.
# Upstream declares only tinygrad>=0.12.0, so the bound is set here.

EAPI=8

LOCAL_AI_PYTHON_NO_VENV=1
LOCAL_AI_PYTHON_NO_TORCH=1
# tinygrad's autogen LLVM-C bindings; the slot's libLLVM path is baked
# into run.sh.
LLVM_COMPAT=( 21 22 23 )

# backend.py's lazy imports: the engine, the vendored model ports, the
# tool-call parsers and the audio/image helpers they load.
LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend
	tinygrad
	tool_parsers
	vendor.appsllm_adapter
	vendor.audio_helpers
	vendor.clip
	vendor.stable_diffusion
	vendor.unet
	vendor.whisper
	tiktoken
	librosa
	soundfile
	PIL"

inherit llvm-r2 local-ai-python

DESCRIPTION="LocalAI tinygrad backend (text, Whisper and Stable Diffusion gRPC server)"

LICENSE="MIT"
IUSE="cuda rocm"
REQUIRED_USE="?? ( cuda rocm )"

# Kernel compilers are run-time dependencies: libLLVM for the CPU
# device, comgr through the HIP runtime for AMD, nvrtc for CUDA.
RDEPEND+="
	sci-ml/huggingface_hub[${PYTHON_SINGLE_USEDEP}]
	$(llvm_gen_dep '
		llvm-core/llvm:${LLVM_SLOT}=
	')
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	rocm? (
		dev-util/hip:=
		dev-libs/rocm-comgr:=
	)
	$(python_gen_cond_dep '
		<sci-ml/tinygrad-0.13[${PYTHON_USEDEP}]
		>=dev-python/jinja2-3.1.0[${PYTHON_USEDEP}]
		dev-python/librosa[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/soundfile[${PYTHON_USEDEP}]
		dev-python/tiktoken[${PYTHON_USEDEP}]
		sci-ml/sentencepiece[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"

# python-single-r1 and llvm-r2 both export pkg_setup.
pkg_setup() {
	python-single-r1_pkg_setup
	llvm-r2_pkg_setup
}

src_install() {
	exeinto "${BACKEND_DIR}"
	doexe backend.py
	insinto "${BACKEND_DIR}"
	doins -r vendor tool_parsers
	python_optimize "${ED}${BACKEND_DIR}"

	if use cuda; then
		LOCAL_AI_PYTHON_RUN_ENV=( "DEV=CUDA" )
	elif use rocm; then
		LOCAL_AI_PYTHON_RUN_ENV=(
			"DEV=HIP"
			"HIP_PATH=${EPREFIX}/usr/$(get_libdir)/libamdhip64.so"
			"COMGR_PATH=${EPREFIX}/usr/$(get_libdir)/libamd_comgr.so"
		)
	else
		LOCAL_AI_PYTHON_RUN_ENV=(
			"DEV=CPU"
			"CPU_LLVM=1"
			"LLVM_PATH=$(get_llvm_prefix)/$(get_libdir)/libLLVM.so"
		)
	fi
	local-ai-python_install_meta
	local-ai-python_smoke_test
}
