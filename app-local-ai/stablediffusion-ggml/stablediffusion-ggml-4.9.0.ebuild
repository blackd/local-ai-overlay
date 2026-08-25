# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI image-generation backend for GGUF-format diffusion models: a
# CGO-free Go gRPC server that dlopens a compute library (libgosd.so) built
# from stable-diffusion.cpp at the exact commit this LocalAI release pins.
# Upstream publishes CPU, CUDA, Vulkan, and SYCL variants of this backend
# but no ROCm build at all; USE=rocm here fills that gap.

EAPI=8

ROCM_VERSION=7.2

inherit cmake cuda go-module local-ai-backend rocm

# The stable-diffusion.cpp commit LocalAI v4.9.0 builds against. Source of
# truth: backend/go/stablediffusion-ggml/Makefile
# (STABLEDIFFUSION_GGML_VERSION) at the upstream release tag; the ggml pin
# is that commit's submodule gitlink (leejet's ggml fork).
SD_COMMIT="de298c225bed97c3f9026b73cd7b71e7879bd41b"
GGML_COMMIT="8e800cef2948046cc47f9db6090491c6128ca42c"

DESCRIPTION="LocalAI image-generation backend (stable-diffusion.cpp gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	https://github.com/mudler/LocalAI/archive/refs/tags/v${PV}.tar.gz -> local-ai-${PV}.tar.gz
	${DISTFILES_BASE}/local-ai-${PV}-deps.tar.xz
	${DISTFILES_BASE}/local-ai-${PV}-prebuilt.tar.xz
	https://github.com/leejet/stable-diffusion.cpp/archive/${SD_COMMIT}.tar.gz -> stable-diffusion.cpp-${SD_COMMIT}.tar.gz
	https://github.com/leejet/ggml/archive/${GGML_COMMIT}.tar.gz -> leejet-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/stablediffusion-ggml"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="cuda native openblas rocm vulkan webp"
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
	webp? ( media-libs/libwebp:= )
"
DEPEND="${RDEPEND}
	vulkan? ( dev-util/vulkan-headers )
"
BDEPEND="
	>=dev-lang/go-1.26
	vulkan? ( media-libs/shaderc )
"

src_unpack() {
	unpack "local-ai-${PV}.tar.gz" "local-ai-${PV}-deps.tar.xz"

	# The Go server imports the generated protobuf package pkg/grpc/proto,
	# shipped in the -prebuilt tarball (rooted at the repo top level).
	cd "${WORKDIR}/LocalAI-${PV}" || die
	unpack "local-ai-${PV}-prebuilt.tar.xz"

	# Assemble the layout upstream's recursive clone would produce. The
	# GitHub archive omits submodule content, so ggml goes in by hand; the
	# unused thirdparty submodules (libwebp/libwebm, web frontend) stay
	# absent and sd.cpp's cmake correctly treats them as unavailable.
	cd "${WORKDIR}" || die
	unpack "stable-diffusion.cpp-${SD_COMMIT}.tar.gz"
	unpack "leejet-ggml-${GGML_COMMIT}.tar.gz"
	mkdir -p "${S}/sources" || die
	mv "stable-diffusion.cpp-${SD_COMMIT}" "${S}/sources/stablediffusion-ggml.cpp" || die
	mv "ggml-${GGML_COMMIT}" "${S}/sources/stablediffusion-ggml.cpp/ggml" || die
}

src_prepare() {
	cmake_src_prepare
	use cuda && cuda_src_prepare
}

src_configure() {
	local mycmakeargs=(
		# ggml RPC backend on, as upstream builds it: generation can be
		# sharded across the same rpc-server workers the llama.cpp
		# backend uses.
		-DSD_RPC=ON
		# Respect the user's CFLAGS instead of -march=native probing,
		# unless they opt in via USE=native.
		-DGGML_NATIVE=$(usex native)
		-DGGML_BLAS=$(usex openblas)
		-DSD_VULKAN=$(usex vulkan)
		-DSD_CUDA=$(usex cuda)
		-DSD_HIPBLAS=$(usex rocm)
		# WebP image output through the system library; sd.cpp otherwise
		# writes PNG/JPEG only.
		-DSD_WEBP=$(usex webp)
		-DSD_USE_SYSTEM_WEBP=$(usex webp)
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
	cmake_src_compile

	# The gRPC server itself: a CGO-free Go binary that dlopens the
	# library built above (its path arrives via SD_LIBRARY from run.sh, so
	# only one compute variant is needed instead of upstream's four).
	cd "${S}" || die
	CGO_ENABLED=0 ego build -o stablediffusion-ggml ./
}

src_install() {
	local-ai-backend_install stablediffusion-ggml "${BUILD_DIR}"/libgosd.so "${S}"/stablediffusion-ggml
}
