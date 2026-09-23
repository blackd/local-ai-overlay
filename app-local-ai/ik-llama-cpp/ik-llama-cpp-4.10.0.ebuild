# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI inference backend for text generation with GGUF-format models:
# LocalAI's grpc-server wrapper compiled together with the ik_llama.cpp
# inference library (ikawrakow's llama.cpp fork, IQ_K quants and faster
# CPU/hybrid inference), at the exact commit this LocalAI release pins and
# patches. Installs entirely under /usr/libexec/local-ai/backends/.

EAPI=8

# Build only the gRPC glue's target; the engine's own binaries are skipped.
LOCAL_AI_CMAKE_TARGET="grpc-server"
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	# Mirrors upstream's backend Makefile: no curl/openssl in the engine.
	-DLLAMA_CURL=OFF
	-DLLAMA_OPENSSL=OFF
)
# ik_llama.cpp forked ggml before the GGML_HIPBLAS -> GGML_HIP rename;
# the eclass default would toggle a nonexistent option and silently
# produce a CPU-only build under USE=rocm.
LOCAL_AI_HIP_CMAKE_VARS="GGML_HIPBLAS"

inherit local-ai-ggml

# The ik_llama.cpp commit LocalAI v4.10.0 builds against. Source of truth:
# backend/cpp/ik-llama-cpp/Makefile (IK_LLAMA_VERSION) at the release tag.
IK_LLAMA_COMMIT="2ae132fa601ea06818ed3584f50f7eb4f72d4967"

DESCRIPTION="LocalAI text-generation backend (ik_llama.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_SRC_URI}
	https://github.com/ikawrakow/ik_llama.cpp/archive/${IK_LLAMA_COMMIT}.tar.gz -> ik_llama.cpp-${IK_LLAMA_COMMIT}.tar.gz
"

# The engine tree must sit at backend/cpp/ik-llama-cpp/llama.cpp inside the
# LocalAI tree: upstream's prepare.sh and the backend CMakeLists assume
# exactly that layout. src_unpack moves it into place.
S="${WORKDIR}/LocalAI-${PV}/backend/cpp/ik-llama-cpp/llama.cpp"

KEYWORDS="~amd64"

RDEPEND+="
	dev-cpp/abseil-cpp:=
	dev-libs/protobuf:=
	net-libs/grpc:=
"
DEPEND+="
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
	# Put ik_llama.cpp where upstream's build system expects it (see S).
	mv "${WORKDIR}/ik_llama.cpp-${IK_LLAMA_COMMIT}" "${S}" || die
}

src_prepare() {
	# Upstream's prepare.sh assembles examples/grpc-server inside the
	# engine tree: applies LocalAI's patches, copies the gRPC wrapper
	# sources and registers the subdirectory with CMake. It is entirely
	# offline, so run it as-is instead of replicating logic that shifts
	# between releases.
	pushd "${WORKDIR}/LocalAI-${PV}/backend/cpp/ik-llama-cpp" >/dev/null || die
	bash ./prepare.sh || die "prepare.sh failed"
	popd >/dev/null || die

	# The gRPC glue links the system abseil stack (see the eclass helper).
	local-ai-backend_bump_cxx20 "${S}/examples/grpc-server/CMakeLists.txt"

	local-ai-ggml_src_prepare
}

src_install() {
	local-ai-backend_gen_run_sh grpc-server LD_LIBRARY_PATH=lib
	local-ai-backend_install ik-llama-cpp "${BUILD_DIR}"/bin/grpc-server
}
