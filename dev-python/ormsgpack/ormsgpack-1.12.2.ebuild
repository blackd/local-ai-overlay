# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# msgpack serialization with a Rust core; fish-speech uses it for its
# TTS request wire format. Rust extension built offline from the
# locked crate graph (the -crates release asset), via maturin. The
# version tracks the fish-speech resolution snapshot — bump alongside
# the local-ai family, not from upstream releases.

EAPI=8

RUST_MIN_VER="1.80.0"
DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=maturin
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 rust

CRATES_BASE="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/ormsgpack-v${PV}"

DESCRIPTION="Fast msgpack serialization for Python, written in Rust"
HOMEPAGE="https://github.com/aviramha/ormsgpack https://pypi.org/project/ormsgpack/"
SRC_URI="
	https://files.pythonhosted.org/packages/source/o/ormsgpack/${P}.tar.gz
	${CRATES_BASE}/${P}-crates.tar.xz
"

LICENSE="|| ( Apache-2.0 MIT )"
# Crate licenses (vendored, statically linked).
LICENSE+=" Apache-2.0 MIT"
SLOT="0"
KEYWORDS="~amd64"

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
