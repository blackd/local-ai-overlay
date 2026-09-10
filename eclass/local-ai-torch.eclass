# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: local-ai-torch.eclass
# @MAINTAINER:
# Plamen K. Kosseff
# @SUPPORTED_EAPIS: 8
# @PROVIDES: cuda distutils-r1 local-ai-rocm rocm
# @BLURB: Shared boilerplate for extensions linking the system pytorch
# @DESCRIPTION:
# Packages building C++ extensions against sci-ml/pytorch (torchcodec,
# torchaudio, ...) share the same skeleton: python-single-r1 lockstep
# with pytorch, cuda/rocm acceleration flags with their toolchain
# dependencies, the ROCm environment torch's exported CMake config
# needs (see local-ai-torch_python_compile), and the pytorch revision
# ladder.
#
# The ladder: libtorch does not keep its C++ ABI stable across minor
# versions and exposes no ABI subslot, so each consumer package is a
# set of -rN revisions identical except for a hard =sci-ml/pytorch-2.X*
# pin, one per pytorch generation the tree carries (declared via
# LOCAL_AI_TORCH_GEN). Portage picks the revision whose pin is
# satisfiable, and a torch generation upgrade forces the switch — an
# ABI rebuild — atomically. When the tree gains a new pytorch, append
# the next -rN with its generation; the nightly dep-bump issue for
# sci-ml/pytorch is the reminder.
#
# Ebuilds must set DISTUTILS_USE_PEP517 and LOCAL_AI_TORCH_GEN before
# inheriting. python_compile() must call local-ai-torch_python_compile
# (a distutils-r1 sub-phase, not exportable via EXPORT_FUNCTIONS).

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_LOCAL_AI_TORCH_ECLASS} ]]; then
_LOCAL_AI_TORCH_ECLASS=1

# @ECLASS_VARIABLE: LOCAL_AI_TORCH_GEN
# @REQUIRED
# @PRE_INHERIT
# @DESCRIPTION:
# The pytorch generation this revision pairs with, e.g. "2.13" —
# becomes the =sci-ml/pytorch-${LOCAL_AI_TORCH_GEN}* ladder pin.
[[ -n ${LOCAL_AI_TORCH_GEN} ]] ||
	die "${ECLASS}: LOCAL_AI_TORCH_GEN must be set before inherit"

PYTHON_COMPAT=( python3_{12..14} )
DISTUTILS_SINGLE_IMPL=1
DISTUTILS_EXT=1

inherit cuda distutils-r1 local-ai-rocm

SLOT="0"

IUSE="cuda rocm"
REQUIRED_USE="
	?? ( cuda rocm )
	rocm? ( ${ROCM_REQUIRED_USE} )
"

# The (-) defaults make one atom form work across the whole ladder:
# pytorch-2.12 predates the cuda/rocm flags, newer generations have
# them and must match.
RDEPEND="
	=sci-ml/pytorch-${LOCAL_AI_TORCH_GEN}*[${PYTHON_SINGLE_USEDEP},cuda(-)?,rocm(-)?]
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	rocm? ( dev-util/hip:= )
"
DEPEND="${RDEPEND}"

# The upstream test suites need network-fetched media fixtures.
RESTRICT="test"

local-ai-torch_src_prepare() {
	use cuda && cuda_src_prepare
	distutils-r1_src_prepare
}

local-ai-torch_src_configure() {
	rocm_add_sandbox -w
	use cuda && cuda_add_sandbox -w
	distutils-r1_src_configure
}

# @FUNCTION: local-ai-torch_python_compile
# @USAGE: [make args passed through to distutils-r1_python_compile]
# @DESCRIPTION:
# Wraps distutils-r1_python_compile with the environment the build
# needs: BUILD_VERSION (honored by both setuptools version probing and
# scikit-build version plugins over version.txt+git), and — under
# USE=rocm — the trio torch's exported CMake config (Caffe2's
# LoadHIP.cmake) requires. LoadHIP runs inside the consumer's
# find_package(Torch): it silently skips defining hip::host unless
# ROCM_PATH names a real ROCm root (default probe /opt/rocm; Gentoo's
# lives in /usr), wants the GPU arch list in PYTORCH_ROCM_ARCH
# (otherwise it shells out to rocm_agent_enumerator, which needs GPU
# device access), and derives the HIP compiler as ROCM_PATH/lib/llvm/
# bin unless HIP_CLANG_PATH points at Gentoo's slotted clang — the
# same three exports pytorch's own ebuild uses.
local-ai-torch_python_compile() {
	export BUILD_VERSION="${PV}"

	if use rocm; then
		local -x ROCM_PATH=/usr
		local -x PYTORCH_ROCM_ARCH="$(get_amdgpu_flags)"
		local -x HIP_CLANG_PATH=$(hipconfig --hipclangpath)
	fi

	distutils-r1_python_compile "$@"
}

EXPORT_FUNCTIONS src_prepare src_configure

fi
