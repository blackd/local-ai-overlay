# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: local-ai-ggml.eclass
# @MAINTAINER:
# Plamen K. Kosseff
# @SUPPORTED_EAPIS: 8
# @PROVIDES: cmake cuda local-ai-backend rocm
# @BLURB: Shared flags, dependencies and CMake phases for ggml-engine backends
# @DESCRIPTION:
# Every LocalAI backend that embeds a ggml-based inference engine shares
# the same acceleration surface: the cuda/native/openblas/rocm/vulkan USE
# flags, their dependencies, and a CMake configuration driving the GGML_*
# toggles plus the ROCm/CUDA toolchain setup. This eclass provides all of
# it; the family-specific eclasses/ebuilds add how the engine is obtained,
# compiled into its final artifact, and installed.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_LOCAL_AI_GGML_ECLASS} ]]; then
_LOCAL_AI_GGML_ECLASS=1

# @ECLASS_VARIABLE: ROCM_VERSION
# @DESCRIPTION:
# ROCm toolchain version the rocm eclass targets; also the floor for the
# HIP/BLAS runtime dependencies.
ROCM_VERSION=7.2

inherit check-reqs cmake cuda local-ai-backend rocm

# @ECLASS_VARIABLE: CHECKREQS_DISK_BUILD
# @DESCRIPTION:
# Build-time disk requirement enforced via check-reqs; the ggml engine
# builds peak around 3G. Ebuilds needing more assign a higher value.
: "${CHECKREQS_DISK_BUILD:=4G}"

# @ECLASS_VARIABLE: LOCAL_AI_CMAKE_TARGET
# @DEFAULT_UNSET
# @DESCRIPTION:
# CMake target to build instead of the default "all".

# @ECLASS_VARIABLE: LOCAL_AI_CUDA_CMAKE_VARS
# @DESCRIPTION:
# Space-separated CMake variable names toggled by USE=cuda; likewise
# LOCAL_AI_VULKAN_CMAKE_VARS (USE=vulkan) and LOCAL_AI_HIP_CMAKE_VARS
# (USE=rocm). Defaults: GGML_CUDA / GGML_VULKAN / GGML_HIP. Engines
# wrapping the toggles in their own option names list them here (e.g.
# "SD_CUDA", or "GGML_CUDA VIBEVOICE_GGML_CUDA" for both at once).

# @ECLASS_VARIABLE: LOCAL_AI_EXTRA_CMAKE_ARGS
# @DEFAULT_UNSET
# @DESCRIPTION:
# Array of engine-specific CMake arguments appended verbatim, e.g.
# ( -DSD_RPC=ON ). May also be extended inside src_configure before
# calling local-ai-ggml_src_configure (e.g. for usex-derived values).

HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
LICENSE="MIT"
SLOT="0"

IUSE="cuda native openblas rocm vulkan"
# Any selected amdgpu_targets_* flag (typically expanded from AMDGPU_TARGETS
# in make.conf) requires USE=rocm — otherwise the target flags apply to a
# non-HIP build and break it. Derive "flag? ( rocm )" for every target the
# rocm eclass knows.
_amdgpu_implies_rocm=""
for _f in ${ROCM_REQUIRED_USE//[!a-z0-9_ ]/}; do
	_amdgpu_implies_rocm+=" ${_f}? ( rocm )"
done
REQUIRED_USE="?? ( cuda rocm ) rocm? ( ${ROCM_REQUIRED_USE} ) ${_amdgpu_implies_rocm}"
unset _amdgpu_implies_rocm _f

# The server package provides the local-ai user and discovers backends
# installed under /usr/libexec via LOCALAI_BACKENDS_SYSTEM_PATH.
RDEPEND="
	sci-ml/local-ai
	openblas? ( sci-libs/openblas )
	vulkan? ( media-libs/vulkan-loader )
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	rocm? (
		>=dev-util/hip-${ROCM_VERSION}
		>=sci-libs/hipBLAS-${ROCM_VERSION}
		>=sci-libs/rocBLAS-${ROCM_VERSION}
	)
"
DEPEND="${RDEPEND}
	vulkan? ( dev-util/vulkan-headers )
"
BDEPEND="
	vulkan? ( media-libs/shaderc )
"

local-ai-ggml_pkg_pretend() {
	check-reqs_pkg_pretend
}

local-ai-ggml_pkg_setup() {
	check-reqs_pkg_setup
}

local-ai-ggml_src_prepare() {
	cmake_src_prepare
	use cuda && cuda_src_prepare
}

local-ai-ggml_src_configure() {
	local mycmakeargs=(
		# Static engine/ggml linked into one self-contained artifact
		# (upstream's default backend build; a no-op where the engine
		# already defaults to static).
		-DBUILD_SHARED_LIBS=OFF
		# Respect the user's CFLAGS instead of -march=native probing,
		# unless they opt in via USE=native.
		-DGGML_NATIVE=$(usex native)
		-DGGML_BLAS=$(usex openblas)
	)
	local v
	for v in ${LOCAL_AI_VULKAN_CMAKE_VARS:-GGML_VULKAN}; do
		mycmakeargs+=( -D${v}=$(usex vulkan) )
	done
	for v in ${LOCAL_AI_CUDA_CMAKE_VARS:-GGML_CUDA}; do
		mycmakeargs+=( -D${v}=$(usex cuda) )
	done
	for v in ${LOCAL_AI_HIP_CMAKE_VARS:-GGML_HIP}; do
		mycmakeargs+=( -D${v}=$(usex rocm) )
	done
	mycmakeargs+=( "${LOCAL_AI_EXTRA_CMAKE_ARGS[@]}" )
	use openblas && mycmakeargs+=( -DGGML_BLAS_VENDOR=OpenBLAS )

	if use rocm; then
		# Switch to hipcc and strip flags it can't digest; build for the
		# GPU architectures selected via AMDGPU_TARGETS USE_EXPAND flags
		# (rocm.eclass) instead of autodetecting the build host's GPU.
		# GPU_TARGETS is ROCm >=6's name for AMDGPU_TARGETS; pass both so
		# the build survives when the legacy name is dropped.
		rocm_use_hipcc
		mycmakeargs+=(
			-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
			-DGPU_TARGETS="$(get_amdgpu_flags)"
			-DCMAKE_HIP_ARCHITECTURES="$(get_amdgpu_flags)"
		)
	fi

	if use cuda; then
		cuda_add_sandbox -w
		addpredict "/dev/char/"
		cuda_sanitize
		mycmakeargs+=( -DCMAKE_CUDA_FLAGS="${NVCCFLAGS}" )
	fi

	cmake_src_configure
}

local-ai-ggml_src_compile() {
	cmake_src_compile ${LOCAL_AI_CMAKE_TARGET}
}

EXPORT_FUNCTIONS pkg_pretend pkg_setup src_prepare src_configure src_compile

fi
