# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# numba's LLVM binding. llvmlite majors pin one LLVM major each
# (0.48+ -> LLVM 22); re-check the pairing at every bump — the
# README's compatibility table is authoritative. Version tracks the
# fish-speech resolution snapshot (via resampy -> numba).

EAPI=8

DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )
LLVM_COMPAT=( 22 )

inherit distutils-r1 llvm-r1

DESCRIPTION="Lightweight LLVM python binding for writing JIT compilers"
HOMEPAGE="https://github.com/numba/llvmlite https://pypi.org/project/llvmlite/"
SRC_URI="https://github.com/numba/llvmlite/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="BSD-2"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="$(llvm_gen_dep 'llvm-core/llvm:${LLVM_SLOT}=')"
RDEPEND="${DEPEND}"

python_configure_all() {
	# ffi/build.py finds LLVM via llvm-config and (newer path) CMake;
	# point both at the slotted install.
	export LLVM_CONFIG="$(get_llvm_prefix)/bin/llvm-config"
	export CMAKE_PREFIX_PATH="$(get_llvm_prefix)"
	# Gentoo's LLVM installs only the monolithic shared libLLVM —
	# no static component archives; link against it.
	export LLVMLITE_SHARED=1
}

python_test() {
	"${EPYTHON}" -m llvmlite.tests || die "tests failed with ${EPYTHON}"
}
