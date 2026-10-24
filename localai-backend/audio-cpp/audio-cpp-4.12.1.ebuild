# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI audio backend (TTS/STT/audio-generation model families) built from
# LocalAI's gRPC wrapper and the pinned audio.cpp engine it embeds. Installs
# entirely under /usr/libexec/local-ai/backends/.

EAPI=8

inherit cmake flag-o-matic local-ai-backend local-ai-rocm toolchain-funcs

# The audio.cpp commit LocalAI v4.12.1 builds against. Source of truth:
# backend/cpp/audio-cpp/Makefile (AUDIO_CPP_VERSION) at the release tag.
AUDIOCPP_COMMIT="0bf4d155f2af5f85853415170622dc145e3d62c3"

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
KEYWORDS="~amd64"
IUSE="+cpu cuda native rocm test vulkan"
# Same CPU kernel gates as local-ai-ggml.eclass (audio-cpp predates it);
# see that eclass for the option-gated-kernels rationale.
_ggml_cpu_flags=( amx_bf16 amx_int8 amx_tile avx avx_vnni avx2 avx512_bf16 avx512bw avx512f avx512vbmi avx512_vnni bmi2 fma3 f16c sse4_2 )
IUSE+=" ${_ggml_cpu_flags[*]/#/cpu_flags_x86_}"
unset _ggml_cpu_flags
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
	use rocm && local-ai-backend_fix_bf16_wmma
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
			# Tree-style CPU kernel gates, matching local-ai-ggml.eclass.
			-DGGML_AMX_BF16=$(usex cpu_flags_x86_amx_bf16)
			-DGGML_AMX_INT8=$(usex cpu_flags_x86_amx_int8)
			-DGGML_AMX_TILE=$(usex cpu_flags_x86_amx_tile)
			-DGGML_AVX=$(usex cpu_flags_x86_avx)
			-DGGML_AVX_VNNI=$(usex cpu_flags_x86_avx_vnni)
			-DGGML_AVX2=$(usex cpu_flags_x86_avx2)
			-DGGML_AVX512_BF16=$(usex cpu_flags_x86_avx512_bf16)
			-DGGML_AVX512_VBMI=$(usex cpu_flags_x86_avx512vbmi)
			-DGGML_AVX512_VNNI=$(usex cpu_flags_x86_avx512_vnni)
			-DGGML_BMI2=$(usex cpu_flags_x86_bmi2)
			-DGGML_F16C=$(usex cpu_flags_x86_f16c)
			-DGGML_FMA=$(usex cpu_flags_x86_fma3)
			-DGGML_SSE42=$(usex cpu_flags_x86_sse4_2)
			-DENGINE_ENABLE_CUDA=$([[ ${v} == cuda ]] && echo ON || echo OFF)
			-DENGINE_ENABLE_HIP=$([[ ${v} == rocm ]] && echo ON || echo OFF)
			-DENGINE_ENABLE_VULKAN=$([[ ${v} == vulkan ]] && echo ON || echo OFF)
			# Engine-logic tests: built once, in the cpu variant.
			-DAUDIO_CPP_GRPC_BUILD_TESTS=$([[ ${v} == cpu ]] && usex test || echo OFF)
		)
		# The base AVX-512 kernels serve both the f and bw subsets.
		if use cpu_flags_x86_avx512f || use cpu_flags_x86_avx512bw; then
			mycmakeargs+=( -DGGML_AVX512=ON )
		else
			mycmakeargs+=( -DGGML_AVX512=OFF )
		fi
		if [[ ${v} == rocm ]]; then
			(
				# Host code on the system compiler; the .cu files go
				# through CMake's HIP language with ROCm clang, named
				# explicitly. The subshell keeps the flag filtering out
				# of the other variants.
				local hipcxx hipflags
				hipcxx=$(tc-getHIPCXX)
				hipflags=$(HIPCXX="${hipcxx}" test-flags-HIPCXX ${CXXFLAGS})
				filter-lto
				local amdgpu_flags
				amdgpu_flags=$(get_amdgpu_flags)
				amdgpu_flags=${amdgpu_flags%;}
				mycmakeargs+=(
					-DCMAKE_HIP_COMPILER="${hipcxx}"
					-DAMDGPU_TARGETS="${amdgpu_flags}"
					-DGPU_TARGETS="${amdgpu_flags}"
					-DCMAKE_HIP_ARCHITECTURES="${amdgpu_flags}"
					# CMake's HIP language ignores CXXFLAGS; pass the
					# filtered set and blank the per-build-type defaults
					# that would otherwise win (-O2 -g -DNDEBUG).
					-DCMAKE_HIP_FLAGS="${hipflags}"
					"-DCMAKE_HIP_FLAGS_${CMAKE_BUILD_TYPE^^}="
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
		# Models without an explicit backend: option run on this
		# variant's engine backend (the wrapper's env fallback patch).
		local-ai-backend_gen_run_sh -e "AUDIOCPP_DEFAULT_BACKEND=${v}" \
			grpc-server LD_LIBRARY_PATH=lib
		local-ai-backend_install "${v}-audio-cpp" --alias audio-cpp \
			"${BUILD_DIR}"/grpc-server
	done
}
