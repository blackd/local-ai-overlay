# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Xet chunk-dedup transfer backend for huggingface-hub (hub >=0.32
# depends on it on x86_64 and uses it for xet-enabled repos). Rust
# extension built offline from the locked crate graph (the -crates
# release asset), via maturin. The version tracks the fish-speech
# resolution snapshot — bump alongside the local-ai family.

EAPI=8

# Verify against the sdist's rust-version at bumps; the xet-core
# workspace tracks recent stable.
RUST_MIN_VER="1.85.0"
DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=maturin
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 rust

CRATES_BASE="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/hf-xet-v${PV}"

DESCRIPTION="Xet storage client for huggingface-hub"
HOMEPAGE="https://github.com/huggingface/xet-core https://pypi.org/project/hf-xet/"
SRC_URI="
	https://files.pythonhosted.org/packages/source/h/hf-xet/hf_xet-${PV}.tar.gz
	${CRATES_BASE}/${P}-crates.tar.xz
"
S="${WORKDIR}/hf_xet-${PV}"

LICENSE="Apache-2.0"
# Crate licenses (vendored, statically linked).
LICENSE+=" MIT BSD ISC Unicode-DFS-2016"
SLOT="0"
KEYWORDS="~amd64"

# Tests exercise the live xet CAS service.
RESTRICT="test"

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
