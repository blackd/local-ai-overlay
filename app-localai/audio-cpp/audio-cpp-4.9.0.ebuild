# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI audio backend (TTS/STT/audio-generation model families) built from
# LocalAI's gRPC wrapper and the pinned audio.cpp engine it embeds. Installs
# entirely under /usr/libexec/local-ai/backends/.

EAPI=8

inherit cmake localai-backend

# The audio.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/cpp/audio-cpp/Makefile (AUDIO_CPP_VERSION) at the release tag.
AUDIOCPP_COMMIT="a61da671b6a81c79071500954eea3c91c1a383dd"

DESCRIPTION="LocalAI audio backend (audio.cpp gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	https://github.com/mudler/LocalAI/archive/refs/tags/v${PV}.tar.gz -> local-ai-${PV}.tar.gz
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

	# Same story as llama-cpp: system abseil is C++20 and its headers force
	# std::*_ordering, so the gRPC glue cannot compile as C++17.
	sed -i 's/set(CMAKE_CXX_STANDARD 17)/set(CMAKE_CXX_STANDARD 20)/' CMakeLists.txt || die
	grep -q 'set(CMAKE_CXX_STANDARD 20)' CMakeLists.txt || die "C++ standard bump did not apply"
}

src_configure() {
	local mycmakeargs=(
		# Compiles the model_specs catalog into the binary so the installed
		# backend needs no model_specs directory (upstream deployment mode).
		-DAUDIOCPP_DEPLOYMENT_BUILD=ON
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
	localai-backend_install audio-cpp "${BUILD_DIR}"/grpc-server
}
