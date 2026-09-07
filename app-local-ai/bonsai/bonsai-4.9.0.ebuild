# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-generation backend for Bonsai 1-bit/ternary models:
# PrismML's llama.cpp fork (Q1_0/Q2_0 weight-quantization kernels),
# compiled with the SAME gRPC glue as app-local-ai/llama-cpp — upstream
# reuses backend/cpp/llama-cpp wholesale and only swaps the engine, and
# so does this ebuild.
#
# At bumps: the fork pin is auto-bumped nightly upstream; the fork-skew
# patch series in backend/cpp/bonsai/patches/ is EMPTY at this release
# but fills up whenever the fork lags an API change the shared
# grpc-server needs (apply-patches.sh consumes it, failing fast when a
# patch stops applying — the retire signal).

EAPI=8

# Build only the gRPC glue's target; the engine's own binaries are skipped.
LOCAL_AI_CMAKE_TARGET="grpc-server"
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	-DLLAMA_CURL=ON
	-DLLAMA_BUILD_TESTS=OFF
	-DLLAMA_BUILD_EXAMPLES=OFF
)

inherit local-ai-ggml

# The PrismML llama.cpp (prism branch) commit LocalAI v4.9.0 pins.
# Source of truth: backend/cpp/bonsai/Makefile (BONSAI_VERSION) at the
# upstream release tag.
BONSAI_COMMIT="312bb2a93ea2bf798333fa859614fbf913ecb9e2"

DESCRIPTION="LocalAI text-generation backend for 1-bit/ternary models (Bonsai fork of llama.cpp)"
SRC_URI="
	${LOCAL_AI_SRC_URI}
	https://github.com/PrismML-Eng/llama.cpp/archive/${BONSAI_COMMIT}.tar.gz -> PrismML-llama.cpp-${BONSAI_COMMIT}.tar.gz
"

# The engine must sit at backend/cpp/llama-cpp/llama.cpp inside the
# LocalAI tree — the shared glue's prepare.sh and CMakeLists assume that
# layout, fork or not. src_unpack moves it into place (the fork's repo
# is also named llama.cpp, so its archive extracts to the same
# llama.cpp-<commit> shape the llama-cpp ebuild relies on).
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
	mv "${WORKDIR}/llama.cpp-${BONSAI_COMMIT}" "${S}" || die
}

src_prepare() {
	local glue="${WORKDIR}/LocalAI-${PV}/backend/cpp/llama-cpp"
	local bonsai="${WORKDIR}/LocalAI-${PV}/backend/cpp/bonsai"

	pushd "${glue}" >/dev/null || die
	# The glue's patch series targets upstream llama.cpp and rejects on
	# the fork; fork-skew patches live in backend/cpp/bonsai/patches/
	# instead (upstream's Makefile does the same removal).
	rm -rf patches || die
	# Adapt the shared gRPC source to the fork's older JSON API and drop
	# the tasks the Bonsai backend does not serve — upstream's exact
	# scripts, run on the same file they run on.
	bash "${bonsai}/patch-grpc-server.sh" ./grpc-server.cpp || die
	bash ./disable-score-task.sh ./grpc-server.cpp || die
	bash ./disable-tts-task.sh ./grpc-server.cpp || die
	# Fork-skew patch series (empty at this pin; fails fast if stale).
	bash "${bonsai}/apply-patches.sh" ./llama.cpp "${bonsai}/patches" || die
	# Assembles tools/grpc-server inside the engine tree, offline.
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
	local-ai-backend_install bonsai "${BUILD_DIR}"/bin/grpc-server
}
