# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI inference backend for text generation with GGUF-format models:
# LocalAI's grpc-server wrapper compiled together with the llama.cpp
# inference library, at the exact llama.cpp commit this LocalAI release pins
# and patches. Installs entirely under /usr/libexec/local-ai/backends/, so it
# co-exists with any system llama-cpp package.

EAPI=8

ROCM_VERSION=7.2

inherit cmake cuda localai-backend rocm

# The llama.cpp commit LocalAI v4.8.2 builds against. Source of truth:
# backend/cpp/llama-cpp/Makefile (LLAMA_VERSION) at the upstream release tag.
LLAMA_COMMIT="221f0f6356efe2260023208365705ec5d5a7c8f5"

DESCRIPTION="LocalAI text-generation backend (llama.cpp gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	https://github.com/mudler/LocalAI/archive/refs/tags/v${PV}.tar.gz -> local-ai-${PV}.tar.gz
	https://github.com/ggerganov/llama.cpp/archive/${LLAMA_COMMIT}.tar.gz -> llama.cpp-${LLAMA_COMMIT}.tar.gz
"

# The llama.cpp tree must sit at backend/cpp/llama-cpp/llama.cpp inside the
# LocalAI tree: upstream's prepare.sh and the backend CMakeLists assume
# exactly that layout. src_unpack moves it into place.
S="${WORKDIR}/LocalAI-${PV}/backend/cpp/llama-cpp/llama.cpp"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="cuda native openblas rocm test vulkan"
REQUIRED_USE="?? ( cuda rocm ) rocm? ( ${ROCM_REQUIRED_USE} )"
RESTRICT="!test? ( test )"

# The server package provides the localai user and the runtime backends
# directory this backend symlinks into. (sci-ml/local-ai's llama-cpp USE
# flag PDEPENDs back on this package; PDEPEND exists precisely to make such
# cycles installable.)
RDEPEND="
	sci-ml/local-ai
	net-misc/curl
	dev-cpp/abseil-cpp:=
	dev-libs/protobuf:=
	net-libs/grpc:=
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
# protoc and grpc_cpp_plugin generate the C++ gRPC stubs from backend.proto
# at build time.
BDEPEND="
	dev-libs/protobuf
	net-libs/grpc
	vulkan? ( media-libs/shaderc )
"

src_unpack() {
	default
	# Put llama.cpp where upstream's build system expects it (see S).
	mv "${WORKDIR}/llama.cpp-${LLAMA_COMMIT}" "${S}" || die
}

src_prepare() {
	# Upstream's prepare.sh assembles tools/grpc-server inside the
	# llama.cpp tree: applies LocalAI's patches, copies the gRPC wrapper
	# sources and helper headers, generates llama_compat.h (a fork-skew
	# probe) and registers the subdirectory with CMake. It is entirely
	# offline, so run it as-is instead of replicating logic that shifts
	# between releases.
	pushd "${WORKDIR}/LocalAI-${PV}/backend/cpp/llama-cpp" >/dev/null || die
	bash ./prepare.sh || die "prepare.sh failed"
	popd >/dev/null || die

	cmake_src_prepare

	use cuda && cuda_src_prepare
}

src_configure() {
	local mycmakeargs=(
		# Static ggml/llama linked into one self-contained grpc-server
		# binary (upstream's default backend build).
		-DBUILD_SHARED_LIBS=OFF
		-DLLAMA_CURL=ON
		-DLLAMA_BUILD_TESTS=OFF
		-DLLAMA_BUILD_EXAMPLES=OFF
		# Respect the user's CFLAGS instead of -march=native probing,
		# unless they opt in via USE=native.
		-DGGML_NATIVE=$(usex native)
		-DGGML_BLAS=$(usex openblas)
		-DGGML_VULKAN=$(usex vulkan)
		-DGGML_CUDA=$(usex cuda)
		-DGGML_HIP=$(usex rocm)
		# LocalAI's own C++ unit tests for the wrapper sources.
		-DLLAMA_GRPC_BUILD_TESTS=$(usex test)
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
	cmake_src_compile grpc-server
}

src_test() {
	cmake_src_test
}

src_install() {
	# LocalAI discovers backends by scanning its backends directory for
	# subdirectories containing run.sh; nothing goes into PATH or the
	# library directories — hence no collision with a system llama-cpp.
	localai-backend_install llama-cpp "${BUILD_DIR}"/tools/grpc-server/grpc-server
}
