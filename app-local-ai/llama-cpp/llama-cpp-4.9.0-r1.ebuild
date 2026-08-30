# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI inference backend for text generation with GGUF-format models:
# LocalAI's grpc-server wrapper compiled together with the llama.cpp
# inference library, at the exact llama.cpp commit this LocalAI release pins
# and patches. Installs entirely under /usr/libexec/local-ai/backends/, so it
# co-exists with any system llama-cpp package.

EAPI=8

# Build only the gRPC glue's target; the engine's own binaries are skipped.
LOCAL_AI_CMAKE_TARGET="grpc-server"
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	-DLLAMA_CURL=ON
	-DLLAMA_BUILD_TESTS=OFF
	-DLLAMA_BUILD_EXAMPLES=OFF
)

inherit local-ai-ggml

# The llama.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/cpp/llama-cpp/Makefile (LLAMA_VERSION) at the upstream release tag.
LLAMA_COMMIT="60addddf3c567c43ec3caf70fc953fba3572d96f"

DESCRIPTION="LocalAI text-generation backend (llama.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_SRC_URI}
	https://github.com/ggerganov/llama.cpp/archive/${LLAMA_COMMIT}.tar.gz -> llama.cpp-${LLAMA_COMMIT}.tar.gz
"

# The llama.cpp tree must sit at backend/cpp/llama-cpp/llama.cpp inside the
# LocalAI tree: upstream's prepare.sh and the backend CMakeLists assume
# exactly that layout. src_unpack moves it into place.
S="${WORKDIR}/LocalAI-${PV}/backend/cpp/llama-cpp/llama.cpp"

KEYWORDS="~amd64"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND+="
	net-misc/curl
	dev-cpp/abseil-cpp:=
	dev-libs/protobuf:=
	net-libs/grpc:=
"
DEPEND+="
	net-misc/curl
	dev-cpp/abseil-cpp:=
	dev-libs/protobuf:=
	net-libs/grpc:=
"
# protoc and grpc_cpp_plugin generate the C++ gRPC stubs from backend.proto
# at build time.
BDEPEND+="
	dev-libs/protobuf
	net-libs/grpc
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

	# The gRPC glue links the system abseil stack (see the eclass helper).
	local-ai-backend_bump_cxx20 "${S}/tools/grpc-server/CMakeLists.txt"

	local-ai-ggml_src_prepare
}

src_configure() {
	# LocalAI's own C++ unit tests for the wrapper sources.
	LOCAL_AI_EXTRA_CMAKE_ARGS+=( -DLLAMA_GRPC_BUILD_TESTS=$(usex test) )
	local-ai-ggml_src_configure
}

src_test() {
	cmake_src_test
}

src_install() {
	local-ai-backend_install llama-cpp "${BUILD_DIR}"/bin/grpc-server
}
