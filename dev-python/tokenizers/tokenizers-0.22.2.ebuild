# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# HuggingFace's tokenizers: the fast Rust tokenization library behind
# transformers. Rust extension built offline from the locked crate
# graph (the -crates release asset), via maturin.
#
# The version is dictated by the transformers pin of the LocalAI
# release: transformers 4.57.6 wants >=0.22.0,<=0.23.0, and no 0.23.0
# final was ever released, so pip resolves 0.22.2 — bump alongside the
# local-ai family, not from upstream releases.

EAPI=8

DISTUTILS_USE_PEP517=maturin
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

CRATES_BASE="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/tokenizers-v${PV}"

DESCRIPTION="Fast tokenizers for research and production"
HOMEPAGE="https://github.com/huggingface/tokenizers https://pypi.org/project/tokenizers/"
SRC_URI="
	https://files.pythonhosted.org/packages/source/t/tokenizers/${P}.tar.gz
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
