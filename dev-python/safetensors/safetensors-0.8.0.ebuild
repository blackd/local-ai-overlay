# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# HuggingFace's safetensors: the tensor-serialization format the python
# ML backends load weights with. Rust extension built offline from the
# locked crate graph (the -crates release asset), via maturin.
#
# The version is dictated by the diffusers/transformers pins of the
# LocalAI release (diffusers 0.38 wants >=0.8.0rc0) — bump alongside
# the local-ai family, not from upstream releases.

EAPI=8

DISTUTILS_USE_PEP517=maturin
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

CRATES_BASE="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/safetensors-v${PV}"

DESCRIPTION="Simple, safe way to store and distribute tensors"
HOMEPAGE="https://github.com/huggingface/safetensors https://pypi.org/project/safetensors/"
SRC_URI="
	https://files.pythonhosted.org/packages/source/s/safetensors/${P}.tar.gz
	${CRATES_BASE}/${P}-crates.tar.xz
"

LICENSE="Apache-2.0"
# Crate licenses (vendored, statically linked).
LICENSE+=" MIT Unicode-DFS-2016"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND=">=virtual/rust-1.80"

src_prepare() {
	distutils-r1_src_prepare

	# Point cargo at the vendored crates; nothing touches the network.
	export CARGO_HOME="${T}/cargo"
	mkdir -p "${CARGO_HOME}" || die
	cat > "${CARGO_HOME}/config.toml" <<-EOF || die
		[source.crates-io]
		replace-with = "vendored"
		[source.vendored]
		directory = "${WORKDIR}/vendor"
	EOF
	export CARGO_NET_OFFLINE=true
}
