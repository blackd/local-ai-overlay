# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-generation backend built on ik_llama.cpp, ikawrakow's
# llama.cpp fork with the IQ-K quantization types and faster CPU/hybrid
# inference: LocalAI's grpc-server wrapper compiled together with the fork
# at the exact commit this LocalAI release pins.

EAPI=8

# Build only the gRPC glue's target; the engine's own binaries are skipped.
# Curl and OpenSSL are switched off as in upstream's backend Makefile.
LOCAL_AI_CMAKE_TARGET="grpc-server"
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	-DLLAMA_CURL=OFF
	-DLLAMA_OPENSSL=OFF
)
# The fork predates ggml's GGML_HIP rename: its ROCm toggle is still the
# old GGML_HIPBLAS (upstream's backend Makefile passes GGML_HIP and would
# silently build CPU-only — presumably why no ROCm variant is published).
LOCAL_AI_HIP_CMAKE_VARS="GGML_HIPBLAS"

inherit local-ai-ggml

# The ik_llama.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/cpp/ik-llama-cpp/Makefile (IK_LLAMA_VERSION) at the upstream
# release tag.
IK_LLAMA_COMMIT="8337e4cd3861406fc04e0854b1409cd1b027fbc9"

DESCRIPTION="LocalAI text-generation backend (ik_llama.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_SRC_URI}
	https://github.com/ikawrakow/ik_llama.cpp/archive/${IK_LLAMA_COMMIT}.tar.gz -> ik_llama.cpp-${IK_LLAMA_COMMIT}.tar.gz
"

# The fork must sit at backend/cpp/ik-llama-cpp/llama.cpp inside the
# LocalAI tree: upstream's prepare.sh assumes exactly that layout.
S="${WORKDIR}/LocalAI-${PV}/backend/cpp/ik-llama-cpp/llama.cpp"

KEYWORDS="~amd64 ~arm64"

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
	# Put the fork where upstream's build system expects it (see S).
	mv "${WORKDIR}/ik_llama.cpp-${IK_LLAMA_COMMIT}" "${S}" || die
}

src_prepare() {
	# Upstream's prepare.sh assembles examples/grpc-server inside the fork
	# tree: applies LocalAI's patches, copies the gRPC wrapper sources and
	# registers the subdirectory with CMake. It is entirely offline, so
	# run it as-is instead of replicating logic that shifts between
	# releases.
	# prepare.sh copies plain files into examples/grpc-server/ assuming the
	# directory exists (the llama-cpp variant's script creates its target
	# as a side effect of a directory copy; this one has no such accident).
	mkdir -p "${S}/examples/grpc-server" || die
	pushd "${WORKDIR}/LocalAI-${PV}/backend/cpp/ik-llama-cpp" >/dev/null || die
	bash ./prepare.sh || die "prepare.sh failed"
	popd >/dev/null || die

	# The gRPC glue links the system abseil stack (see the eclass helper).
	local-ai-backend_bump_cxx20 "${S}/examples/grpc-server/CMakeLists.txt"

	local-ai-ggml_src_prepare
}

src_install() {
	local-ai-backend_install ik-llama-cpp "${BUILD_DIR}"/bin/grpc-server
}
