# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# tinygrad, a small tensor library with its own runtime: kernels are
# generated per device and compiled at run time, through libLLVM or a
# clang subprocess for the CPU device, through comgr for AMD GPUs,
# through nvrtc for CUDA. None of those are needed to build or import
# the package, only to run on the device in question, so they are
# declared by the consumer (localai-backend/tinygrad) per USE flag. The
# package itself has no Python dependencies.
#
# tinygrad finds its libraries by listing /usr/lib64 and friends, not
# through the loader, so Gentoo's slotted libLLVM has to be named
# explicitly (LLVM_PATH). The shipped test runs on the CPU device with
# the in-process LLVM renderer (DEV=CPU:LLVM).

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )
LLVM_COMPAT=( 21 22 23 )
LLVM_OPTIONAL=1

inherit distutils-r1 llvm-r2 pypi

DESCRIPTION="A simple and fast tensor library with its own device runtimes"
HOMEPAGE="https://tinygrad.org https://github.com/tinygrad/tinygrad https://pypi.org/project/tinygrad/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
REQUIRED_USE="test? ( ${LLVM_REQUIRED_USE} )"

BDEPEND="
	test? (
		$(llvm_gen_dep '
			llvm-core/llvm:${LLVM_SLOT}
		')
	)
"

distutils_enable_tests pytest

pkg_setup() {
	use test && llvm-r2_pkg_setup
}

python_test() {
	local -x DEV="CPU:LLVM"
	local -x LLVM_PATH="$(get_llvm_prefix)/$(get_libdir)/libLLVM.so"
	epytest test/test_tiny.py
}
