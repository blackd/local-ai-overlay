# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI audio backend (TTS/STT/audio-generation model families) built from
# LocalAI's gRPC wrapper and the pinned audio.cpp engine it embeds. Installs
# entirely under /usr/libexec/local-ai/backends/.

EAPI=8

inherit cmake local-ai-backend

# The audio.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/cpp/audio-cpp/Makefile (AUDIO_CPP_VERSION) at the release tag.
AUDIOCPP_COMMIT="a61da671b6a81c79071500954eea3c91c1a383dd"

DESCRIPTION="LocalAI audio backend (audio.cpp gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	${LOCAL_AI_SRC_URI}
	https://github.com/0xShug0/audio.cpp/archive/${AUDIOCPP_COMMIT}.tar.gz -> audio.cpp-${AUDIOCPP_COMMIT}.tar.gz
"

# The backend directory is itself the CMake project root; it expects the
# engine checkout at ./audio.cpp (moved into place in src_unpack).
S="${WORKDIR}/LocalAI-${PV}/backend/cpp/audio-cpp"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="cuda native test vulkan"
REQUIRED_USE="?? ( cuda vulkan )"
RESTRICT="!test? ( test )"

RDEPEND="
	sci-ml/local-ai
	dev-cpp/abseil-cpp:=
	dev-libs/protobuf:=
	net-libs/grpc:=
	vulkan? ( media-libs/vulkan-loader )
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
"
DEPEND="${RDEPEND}
	vulkan? ( dev-util/vulkan-headers )
"
BDEPEND="
	dev-libs/protobuf
	net-libs/grpc
	vulkan? ( media-libs/shaderc )
"

src_unpack() {
	default
	mv "${WORKDIR}/audio.cpp-${AUDIOCPP_COMMIT}" "${S}/audio.cpp" || die
}

src_prepare() {
	cmake_src_prepare

	# System abseil requires C++20 tree-wide here: sentencepiece links it,
	# and the cxx_std_20 INTERFACE feature propagates through it to the
	# whole tree. The engine's sources are C++17-clean except for u8
	# string literals (char8_t* since C++20); stripping the prefix yields
	# byte-identical plain UTF-8 literals in either standard.
	local files=()
	readarray -t files < <(grep -rl 'CMAKE_CXX_STANDARD 17' .)
	local-ai-backend_bump_cxx20 "${files[@]}"
	einfo "Stripping u8 string literal prefixes from engine sources"
	find "${S}/audio.cpp/src" \( -name '*.cpp' -o -name '*.h' \) -exec sed -i 's/\bu8"/"/g' {} + || die
}

src_configure() {
	local mycmakeargs=(
		# Compiles the model_specs catalog into the binary so the installed
		# backend needs no model_specs directory (upstream deployment mode).
		-DAUDIOCPP_DEPLOYMENT_BUILD=ON
		# sentencepiece's absl shim headers reuse real abseil's include
		# guards and shadow it via -I third_party, which cannot coexist
		# with the system protobuf headers (they include real abseil).
		# The "package" provider replaces the shim directory with a
		# symlink to the system abseil headers: one absl for every
		# translation unit. (SPM_PROTOBUF_PROVIDER stays "package" —
		# upstream FORCEs it, see their CMakeLists for the two-runtimes
		# ABI war story.)
		-DSPM_ABSL_PROVIDER=package
		# One host-targeted build (per CFLAGS) instead of upstream's
		# dlopen-able per-microarch ggml fan-out for fat container images.
		-DENGINE_ENABLE_CPU_ALL_VARIANTS=OFF
		-DGGML_NATIVE=$(usex native)
		-DENGINE_ENABLE_CUDA=$(usex cuda)
		-DENGINE_ENABLE_VULKAN=$(usex vulkan)
		-DAUDIO_CPP_GRPC_BUILD_TESTS=$(usex test)
	)
	cmake_src_configure
}

src_compile() {
	cmake_src_compile
}

src_test() {
	cmake_src_test
}

src_install() {
	local-ai-backend_install audio-cpp "${BUILD_DIR}"/grpc-server
}
