# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# PyTorch quantisation and sparsity library, a dependency of neucodec
# and ACE-Step. Built from the GitHub tag: PyPI has no sdist. With
# USE_CPP=0 setup.py skips every C++/CUDA extension and produces the
# same pure-python package upstream publishes as its py3-none-any
# wheel; the quantisation paths run on torch ops and, where installed,
# Triton. The version suffix is forced empty, otherwise setup.py asks
# git for a commit id the tarball cannot provide. torch is a build-time
# import of setup.py as well.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

DESCRIPTION="PyTorch native quantization and sparsity for training and inference"
HOMEPAGE="https://github.com/pytorch/ao https://pypi.org/project/torchao/"
SRC_URI="https://github.com/pytorch/ao/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"
S="${WORKDIR}/ao-${PV}"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
# The suite wants GPUs, transformers and the dev extras.
RESTRICT="test"

RDEPEND="
	sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/typing-extensions[${PYTHON_USEDEP}]
	')
"
BDEPEND="sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]"

export USE_CPP=0
export VERSION_SUFFIX=""

src_prepare() {
	distutils-r1_src_prepare
	# find_packages() only excludes benchmarks; test/ has __init__.py files
	# and would be installed as a top-level "test" package.
	sed -i 's/find_packages(exclude=\["benchmarks", "benchmarks\.\*"\])/find_packages(exclude=["benchmarks", "benchmarks.*", "test", "test.*"])/' setup.py || die
	grep -q '"test", "test\.\*"' setup.py || die "package exclusion not applied"
}

python_install_all() {
	distutils-r1_python_install_all
	# The import surface the consumers touch has to resolve without
	# Triton, which the tree does not have.
	PYTHONPATH="${D}$(python_get_sitedir)" "${EPYTHON}" -c "import torchao, torchao.quantization, torchao.dtypes" || die "torchao import check failed"
}
