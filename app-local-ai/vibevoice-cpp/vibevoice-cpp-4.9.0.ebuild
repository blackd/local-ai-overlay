# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-to-speech backend for Microsoft's VibeVoice model in GGUF
# format: a CGO-free Go gRPC server that dlopens a compute library
# (libgovibevoicecpp.so) built from mudler's vibevoice.cpp at the exact
# commit this LocalAI release pins.

EAPI=8

ROCM_VERSION=7.2

inherit cmake cuda go-module local-ai-backend rocm

# The vibevoice.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/go/vibevoice-cpp/Makefile (VIBEVOICE_CPP_VERSION) at the upstream
# release tag; the ggml pin is that commit's third_party/ggml submodule
# gitlink (ggml-org's mainline ggml).
VIBEVOICE_COMMIT="000e37282bc5bb09edc20f7047a47924122ba3a0"
GGML_COMMIT="8be60f83ec124c31f3a427053c29022e3072f8a4"

DESCRIPTION="LocalAI text-to-speech backend (vibevoice.cpp gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/mudler/vibevoice.cpp/archive/${VIBEVOICE_COMMIT}.tar.gz -> vibevoice.cpp-${VIBEVOICE_COMMIT}.tar.gz
	https://github.com/ggml-org/ggml/archive/${GGML_COMMIT}.tar.gz -> ggml-org-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/vibevoice-cpp"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="cuda native openblas rocm vulkan"
# Any selected amdgpu_targets_* flag (typically expanded from AMDGPU_TARGETS
# in make.conf) requires USE=rocm — otherwise the target flags apply to a
# non-HIP build and break it. Derive "flag? ( rocm )" for every target the
# eclass knows.
_amdgpu_implies_rocm=""
for _f in ${ROCM_REQUIRED_USE//[!a-z0-9_ ]/}; do
	_amdgpu_implies_rocm+=" ${_f}? ( rocm )"
done
REQUIRED_USE="?? ( cuda rocm ) rocm? ( ${ROCM_REQUIRED_USE} ) ${_amdgpu_implies_rocm}"
unset _amdgpu_implies_rocm _f

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
	>=dev-lang/go-1.26
	vulkan? ( media-libs/shaderc )
"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ggml-org-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" third_party/ggml )
	local-ai-backend_engine_unpack "vibevoice.cpp-${VIBEVOICE_COMMIT}.tar.gz" vibevoice.cpp "${ggml[@]}"
}

src_prepare() {
	cmake_src_prepare
	use cuda && cuda_src_prepare
}

src_configure() {
	local mycmakeargs=(
		# Static libvibevoice/ggml whole-archived into one self-contained
		# module library (upstream's default backend build).
		-DBUILD_SHARED_LIBS=OFF
		# Respect the user's CFLAGS instead of -march=native probing,
		# unless they opt in via USE=native.
		-DGGML_NATIVE=$(usex native)
		-DGGML_BLAS=$(usex openblas)
		-DGGML_VULKAN=$(usex vulkan)
		-DVIBEVOICE_GGML_VULKAN=$(usex vulkan)
		-DGGML_CUDA=$(usex cuda)
		-DVIBEVOICE_GGML_CUDA=$(usex cuda)
		# This ggml only understands GGML_HIP (GGML_HIPBLAS was removed
		# upstream and silently produced CPU-only builds).
		-DGGML_HIP=$(usex rocm)
	)
	use openblas && mycmakeargs+=( -DGGML_BLAS_VENDOR=OpenBLAS )

	if use rocm; then
		# Switch to hipcc and strip flags it can't digest; build for the
		# GPU architectures selected via AMDGPU_TARGETS USE_EXPAND flags
		# (rocm.eclass) instead of autodetecting the build host's GPU.
		rocm_use_hipcc
		mycmakeargs+=(
			-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
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

src_compile() {
	# The engine subdirectory is EXCLUDE_FROM_ALL; the govibevoicecpp
	# target pulls libvibevoice in as its link dependency.
	cmake_src_compile govibevoicecpp

	# The gRPC server itself: a CGO-free Go binary that dlopens the
	# library built above (its path arrives via VIBEVOICECPP_LIBRARY from
	# run.sh, so only one compute variant is needed instead of upstream's
	# four).
	cd "${S}" || die
	CGO_ENABLED=0 ego build -o vibevoice-cpp ./
}

src_install() {
	local-ai-backend_install vibevoice-cpp "${BUILD_DIR}"/libgovibevoicecpp.so "${S}"/vibevoice-cpp
}
