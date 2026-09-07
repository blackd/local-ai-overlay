# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-generation backend built on mudler's vllm.cpp — NOT a
# ggml engine: its own C++ runtime with per-file SIMD dispatch (one
# portable CPU library, no -march variant builds), a stable C ABI, and
# opt-in GPU backends, so this ebuild does not use the ggml eclasses.
# Packaged accelerator: Vulkan (headers vendored, the driver is
# dlopened at runtime — no build-time Vulkan dependencies). CUDA is not
# offered: the engine requires the CUDA 13 toolchain and ::gentoo tops
# out at 12.9. ROCm (VLLM_CPP_HIP) exists upstream but is untested by
# LocalAI's own builds. Revisit both at later bumps.
#
# The LocalAI backend dir may carry patches/*.patch for the engine
# (loud-fail git apply in its Makefile) — EMPTY at this release; at
# bumps check for new ones and eapply them onto sources/vllm.cpp.

EAPI=8

inherit cmake go-module local-ai-backend

# The vllm.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/go/vllm-cpp/Makefile (VLLM_CPP_VERSION) at the release tag.
VLLM_COMMIT="438305e1577768ec0f75729456a4c8b9f425e2ee"

DESCRIPTION="LocalAI text-generation backend (vllm.cpp gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/mudler/vllm.cpp/archive/${VLLM_COMMIT}.tar.gz -> vllm.cpp-${VLLM_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/vllm-cpp"
CMAKE_USE_DIR="${S}/sources/vllm.cpp"

LICENSE="Apache-2.0 MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="vulkan video_cards_amdgpu"

RDEPEND="
	sci-ml/local-ai
	vulkan? (
		media-libs/vulkan-loader
		video_cards_amdgpu? ( media-libs/mesa[vulkan,video_cards_radeonsi] )
	)
"
BDEPEND=">=dev-lang/go-1.26.0"

src_unpack() {
	local-ai-backend_go_unpack
	local-ai-backend_engine_unpack "vllm.cpp-${VLLM_COMMIT}.tar.gz" vllm.cpp
}

src_prepare() {
	# Upstream's abi-check: govllmcpp.go mirrors vllm.h structs by hand;
	# without this a drifted pin surfaces only at runtime, at model load.
	local engine backend
	engine=$(sed -n 's/^#define VLLM_ABI_VERSION \([0-9][0-9]*\).*/\1/p' \
		"${CMAKE_USE_DIR}/include/vllm.h")
	backend=$(sed -n 's/^const abiVersion = \([0-9][0-9]*\).*/\1/p' govllmcpp.go)
	[[ -n ${engine} && ${engine} == "${backend}" ]] || \
		die "vllm.h ABI v${engine:-?} does not match govllmcpp.go v${backend:-?}"

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		# The backend consumes only the stable C ABI; the engine's
		# server, examples and tests are never built here.
		-DVLLM_CPP_SERVER=OFF
		-DVLLM_CPP_BUILD_TESTS=OFF
		-DVLLM_CPP_BUILD_EXAMPLES=OFF
		-DVLLM_CPP_VULKAN=$(usex vulkan)
	)
	cmake_src_configure
}

src_compile() {
	cmake_src_compile vllm_shared

	cd "${S}" || die
	CGO_ENABLED=0 ego build -o vllm-cpp ./
}

src_install() {
	local-ai-backend_install vllm-cpp "${BUILD_DIR}/libvllm.so" "${S}/vllm-cpp"
}
