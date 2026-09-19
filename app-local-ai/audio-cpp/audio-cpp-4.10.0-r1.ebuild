# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI audio backend (TTS/STT/audio-generation model families) built from
# LocalAI's gRPC wrapper and the pinned audio.cpp engine it embeds. Installs
# entirely under /usr/libexec/local-ai/backends/.

EAPI=8

inherit cmake local-ai-backend local-ai-rocm

# The audio.cpp commit LocalAI v4.10.0 builds against. Source of truth:
# backend/cpp/audio-cpp/Makefile (AUDIO_CPP_VERSION) at the release tag.
AUDIOCPP_COMMIT="4af143229384fb6da3f373dc87de145ae954609b"

DESCRIPTION="LocalAI audio backend (audio.cpp gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	${LOCAL_AI_SRC_URI}
	https://github.com/0xShug0/audio.cpp/archive/${AUDIOCPP_COMMIT}.tar.gz -> audio.cpp-${AUDIOCPP_COMMIT}.tar.gz
"

# The backend directory is itself the CMake project root; it expects the
# engine checkout at ./audio.cpp (moved into place in src_unpack).
S="${WORKDIR}/LocalAI-${PV}/backend/cpp/audio-cpp"

# Backend option env fallback (AUDIOCPP_DEFAULT_BACKEND) — proposed
# upstream; see the patch header.
PATCHES=( "${FILESDIR}/${P}-default-backend-env.patch" )

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+cpu cuda native rocm test vulkan"
# Each enabled flag builds its own co-installable backend variant
# (upstream's model: cpu-/cuda-/rocm-/vulkan-audio-cpp, all aliased to
# audio-cpp — the server resolves the alias by host capability, and a
# model YAML can pin a concrete variant, e.g. cpu-audio-cpp to spare
# VRAM). Tests are engine-logic tests; one build of them suffices.
REQUIRED_USE="
	|| ( cpu cuda rocm vulkan )
	rocm? ( ${ROCM_REQUIRED_USE} )
	test? ( cpu )
"
RESTRICT="!test? ( test )"

RDEPEND="
	sci-ml/local-ai
	dev-cpp/abseil-cpp:=
	dev-libs/protobuf:=
	net-libs/grpc:=
	vulkan? ( media-libs/vulkan-loader )
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	rocm? (
		>=dev-util/hip-${ROCM_VERSION}:=
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=
		>=sci-libs/rocBLAS-${ROCM_VERSION}:=
	)
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
	[[ ${#files[@]} -gt 0 ]] || die "no CMAKE_CXX_STANDARD 17 anchors found — engine build layout changed"
	local-ai-backend_bump_cxx20 "${files[@]}"
	einfo "Stripping u8 string literal prefixes from engine sources"
	find "${S}/audio.cpp/src" \( -name '*.cpp' -o -name '*.h' \) -exec sed -i 's/\bu8"/"/g' {} + || die
	# The method form of the same char8_t break: path::u8string() returns
	# std::u8string since C++20 (std::string in C++17, which upstream
	# builds as); the bytes are identical UTF-8 either way on Linux.
	einfo "Replacing path::u8string() calls in engine sources"
	find "${S}/audio.cpp/src" \( -name '*.cpp' -o -name '*.h' \) -exec sed -i 's/\.u8string()/.string()/g' {} + || die
}

# Enabled variants, in the order they build.
audio_cpp_variants() {
	use cpu && echo cpu
	use cuda && echo cuda
	use rocm && echo rocm
	use vulkan && echo vulkan
	return 0
}

src_configure() {
	local v
	for v in $(audio_cpp_variants); do
		local BUILD_DIR="${WORKDIR}/${P}_build-${v}"
		local mycmakeargs=(
			# No C++20 modules anywhere in the tree: the scan otherwise
			# runs clang-scan-deps (from a DIFFERENT llvm than rocm's
			# clang) against every hipcc command as plain C++.
			-DCMAKE_CXX_SCAN_FOR_MODULES=OFF
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
			-DENGINE_ENABLE_CUDA=$([[ ${v} == cuda ]] && echo ON || echo OFF)
			-DENGINE_ENABLE_HIP=$([[ ${v} == rocm ]] && echo ON || echo OFF)
			-DENGINE_ENABLE_VULKAN=$([[ ${v} == vulkan ]] && echo ON || echo OFF)
			# Engine-logic tests: built once, in the cpu variant.
			-DAUDIO_CPP_GRPC_BUILD_TESTS=$([[ ${v} == cpu ]] && usex test || echo OFF)
		)
		if [[ ${v} == rocm ]]; then
			(
				# Upstream drives this build with ROCm clang rather than
				# hipcc: hipcc treats every .cpp as HIP source and
				# device-compiles it for its built-in default arch
				# (gfx906) when no offload arch is passed — the kernels'
				# archs already travel via CMAKE_HIP_ARCHITECTURES. The
				# subshell keeps CC/CXX out of the other variants;
				# CMake caches the compilers, so compile needs no env.
				local hipclang
				hipclang=$(hipconfig --hipclangpath) && [[ -n ${hipclang} ]] \
					|| die "hipconfig --hipclangpath failed"
				local -x CC="${hipclang}/clang" CXX="${hipclang}/clang++"
				local amdgpu_flags
				amdgpu_flags=$(get_amdgpu_flags)
				amdgpu_flags=${amdgpu_flags%;}
				mycmakeargs+=(
					-DAMDGPU_TARGETS="${amdgpu_flags}"
					-DGPU_TARGETS="${amdgpu_flags}"
					-DCMAKE_HIP_ARCHITECTURES="${amdgpu_flags}"
				)
				cmake_src_configure
			) || die
		else
			cmake_src_configure
		fi
	done
}

src_compile() {
	local v
	for v in $(audio_cpp_variants); do
		local BUILD_DIR="${WORKDIR}/${P}_build-${v}"
		cmake_src_compile
	done
}

src_test() {
	local BUILD_DIR="${WORKDIR}/${P}_build-cpu"
	cmake_src_test
}

src_install() {
	local v
	for v in $(audio_cpp_variants); do
		local BUILD_DIR="${WORKDIR}/${P}_build-${v}"
		local-ai-backend_gen_run_sh grpc-server LD_LIBRARY_PATH=lib
		local-ai-backend_install "${v}-audio-cpp" --alias audio-cpp \
			"${BUILD_DIR}"/grpc-server
	done
}
