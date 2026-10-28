# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# OpenNMT's Transformer inference engine, the library behind
# faster-whisper and whisperx. Built from the GitHub tag: PyPI ships
# binary wheels only. The tarball's submodule directories are empty;
# spdlog and cxxopts come from the tree, cpu_features and ruy from
# pinned tarballs of the commits upstream tracks, ruy's own cpuinfo
# from dev-libs/cpuinfo. Upstream defaults to Intel MKL and the Intel
# OpenMP runtime; here the CPU GEMM backends are USE-selected and
# OpenMP is the compiler's. ENABLE_CPU_DISPATCH compiles the kernels
# for AVX, AVX2 and AVX-512 and picks at run time. CUDA (legacy
# FindCUDA plus the cutlass/thrust submodules) is not wired.

EAPI=8

inherit cmake flag-o-matic local-ai-rocm toolchain-funcs

CPU_FEATURES_COMMIT="8a494eb1e158ec2050e5f699a504fbc9b896a43b"
RUY_COMMIT="363f252289fb7a1fba1703d99196524698cb884d"

DESCRIPTION="Fast inference engine for Transformer models"
HOMEPAGE="https://opennmt.net/CTranslate2 https://github.com/OpenNMT/CTranslate2"
SRC_URI="
	https://github.com/OpenNMT/CTranslate2/archive/refs/tags/v${PV}.tar.gz -> CTranslate2-${PV}.gh.tar.gz
	https://github.com/google/cpu_features/archive/${CPU_FEATURES_COMMIT}.tar.gz -> cpu_features-${CPU_FEATURES_COMMIT}.tar.gz
	ruy? ( https://github.com/google/ruy/archive/${RUY_COMMIT}.tar.gz -> ruy-${RUY_COMMIT}.tar.gz )
"
S="${WORKDIR}/CTranslate2-${PV}"

# CPU dispatch: pin each per-ISA copy of kernels.cc to its own ISA so the
# global -march cannot collapse them onto one instantiation.
PATCHES=( "${FILESDIR}/${P}-dispatch-isa.patch" )

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+cli dnnl +openblas +openmp rocm +ruy"
# At least one CPU GEMM backend. ROCm needs the HIP toolchain targets.
REQUIRED_USE="|| ( dnnl openblas ruy ) rocm? ( ${ROCM_REQUIRED_USE} )"
# The suite is built against the googletest submodule.
RESTRICT="test"

RDEPEND="
	dev-cpp/nlohmann_json
	dev-libs/spdlog:=
	dnnl? ( sci-ml/oneDNN:= )
	openblas? ( sci-libs/openblas:= )
	rocm? (
		>=dev-util/hip-${ROCM_VERSION}:=
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=
		>=sci-libs/hipCUB-${ROCM_VERSION}:=
		>=sci-libs/hipRAND-${ROCM_VERSION}:=
		>=sci-libs/rocPRIM-${ROCM_VERSION}:=
		>=sci-libs/rocThrust-${ROCM_VERSION}:=
		openmp? ( llvm-runtimes/openmp )
	)
	ruy? ( dev-libs/cpuinfo:= )
"
DEPEND="${RDEPEND}
	cli? ( dev-libs/cxxopts )
"

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

src_unpack() {
	default
	# Drop into the empty submodule directories the build expects.
	rmdir "${S}"/third_party/cpu_features || die
	mv "${WORKDIR}/cpu_features-${CPU_FEATURES_COMMIT}" "${S}"/third_party/cpu_features || die
	if use ruy; then
		rmdir "${S}"/third_party/ruy || die
		mv "${WORKDIR}/ruy-${RUY_COMMIT}" "${S}"/third_party/ruy || die
	fi
}

src_prepare() {
	cmake_src_prepare

	# A copy of nlohmann_json 3.11.2 under include/ that the install rule
	# would ship over dev-cpp/nlohmann_json's; the sources include it by
	# the same <nlohmann/json.hpp> path, so the system header serves.
	rm -r include/nlohmann || die

	# System spdlog: its config exports the same spdlog::spdlog_header_only
	# target the vendored subdirectory would.
	sed -i 's|^add_subdirectory(third_party/spdlog EXCLUDE_FROM_ALL)$|find_package(spdlog REQUIRED)|' CMakeLists.txt || die
	grep -q 'find_package(spdlog REQUIRED)' CMakeLists.txt || die "spdlog substitution did not apply"

	# System cxxopts for the CLI: drop the submodule check and include dir.
	sed -i -e '/^if (NOT IS_DIRECTORY/,/^endif()$/d' -e '/^target_include_directories(translator$/,/^  )$/d' cli/CMakeLists.txt || die
	grep -q 'third_party' cli/CMakeLists.txt && die "cxxopts submodule reference left in cli/CMakeLists.txt"
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_CLI=$(usex cli)
		-DBUILD_TESTS=OFF
		-DBUILD_SHARED_LIBS=ON
		-DENABLE_CPU_DISPATCH=ON
		-DOPENMP_RUNTIME=$(usex openmp COMP NONE)
		-DWITH_MKL=OFF
		-DWITH_DNNL=$(usex dnnl)
		-DWITH_OPENBLAS=$(usex openblas)
		-DWITH_RUY=$(usex ruy)
		-DWITH_CUDA=OFF
		-DWITH_HIP=$(usex rocm)
	)
	if use ruy; then
		mycmakeargs+=( -DRUY_FIND_CPUINFO=ON -DRUY_MINIMAL_BUILD=ON )
	fi
	if use rocm; then
		# rocThrust and hipCUB link hip::device, whose interface compile
		# options put -x hip on every source of the target, CPU files
		# included. Those go to the CXX compiler, so the ROCm clang has to
		# be the CXX compiler as well, as upstream's CXX=hipcc builds do;
		# the ggml eclass's host-gcc split only works with hip::host.
		local hipcxx hipflags
		hipcxx=$(tc-getHIPCXX)
		hipflags=$(HIPCXX="${hipcxx}" test-flags-HIPCXX ${CXXFLAGS})
		filter-lto
		export CXX="${hipcxx}"
		strip-unsupported-flags
		export ROCM_PATH="${EPREFIX}/usr"
		mycmakeargs+=(
			-DCMAKE_HIP_COMPILER="${hipcxx}"
			-DCMAKE_HIP_ARCHITECTURES="$(get_amdgpu_flags)"
			-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
			-DGPU_TARGETS="$(get_amdgpu_flags)"
			-DCMAKE_HIP_FLAGS="${hipflags}"
			"-DCMAKE_HIP_FLAGS_${CMAKE_BUILD_TYPE^^}="
		)
	fi
	cmake_src_configure
}
