# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# opencode's persistent PTY daemon: owns the terminal child processes
# (portable-pty) and keeps terminal state through libghostty-vt. Rust,
# built from the crates.io set in Cargo.lock. Upstream's build.rs clones
# Ghostty from GitHub at a pinned commit and runs zig on it to get
# libghostty-vt.a; the patch here makes it take the archive from
# dev-libs/libghostty-vt instead, a snapshot of exactly that commit
# under /usr/lib64/libghostty-vt-opencode. The archive carries simdutf
# and highway, so nothing else is linked. dev-util/opencode embeds the
# resulting binary through OPENCODE_PTY_BIN.

EAPI=8

CRATES="
	anyhow@1.0.104
	base64@0.22.1
	bitflags@1.3.2
	bitflags@2.13.1
	block-buffer@0.10.4
	cfg-if@1.0.4
	cfg_aliases@0.1.1
	cpufeatures@0.2.17
	crossbeam-channel@0.5.16
	crossbeam-utils@0.8.22
	crypto-common@0.1.7
	digest@0.10.7
	downcast-rs@1.2.1
	filedescriptor@0.8.3
	fs2@0.4.3
	generic-array@0.14.7
	getrandom@0.3.4
	itoa@1.0.18
	lazy_static@1.5.0
	libc@0.2.189
	log@0.4.33
	memchr@2.8.3
	nix@0.28.0
	portable-pty@0.9.0
	ppv-lite86@0.2.21
	proc-macro2@1.0.107
	quote@1.0.47
	r-efi@5.3.0
	rand@0.9.5
	rand_chacha@0.9.0
	rand_core@0.9.5
	serde@1.0.229
	serde_core@1.0.229
	serde_derive@1.0.229
	serde_json@1.0.151
	serial2@0.2.38
	sha2@0.10.9
	shared_library@0.1.9
	shell-words@1.1.1
	syn@2.0.119
	syn@3.0.3
	thiserror-impl@1.0.69
	thiserror@1.0.69
	typenum@1.20.1
	unicode-ident@1.0.24
	version_check@0.9.5
	wasip2@1.0.4+wasi-0.2.12
	winapi-i686-pc-windows-gnu@0.4.0
	winapi-x86_64-pc-windows-gnu@0.4.0
	winapi@0.3.9
	windows-link@0.2.1
	windows-sys@0.61.2
	winreg@0.10.1
	wit-bindgen@0.57.1
	zerocopy-derive@0.8.56
	zerocopy@0.8.56
	zmij@1.0.23
"

RUST_MIN_VER="1.90.0"

inherit cargo

DESCRIPTION="Persistent PTY service for opencode"
HOMEPAGE="https://github.com/anomalyco/opencode-pty"
SRC_URI="
	https://github.com/anomalyco/opencode-pty/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz
	${CARGO_CRATE_URIS}
"

LICENSE="MIT"
# Crates, and the libghostty-vt archive linked in (Ghostty MIT, simdutf
# and highway Apache-2.0).
LICENSE+=" Apache-2.0 MIT Unicode-3.0"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="dev-libs/libghostty-vt"

PATCHES=( "${FILESDIR}/${P}-system-ghostty-vt.patch" )

src_prepare() {
	default
	# Portage strips and keeps the debug info; cargo must not pre-empt it.
	sed -i '/^strip = "symbols"$/d' Cargo.toml || die
	grep -q '^strip = ' Cargo.toml && die "strip setting still in Cargo.toml"
}

src_configure() {
	# Where the patched build.rs finds libghostty-vt.a.
	export GHOSTTY_VT_LIB_DIR="${EPREFIX}/usr/$(get_libdir)/libghostty-vt-opencode"
	cargo_src_configure
}
