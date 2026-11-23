# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# opencode is an AI coding agent (terminal UI + web UI) written in
# TypeScript and compiled with Bun into a single self-contained binary.
# Prebuilt components: Bun itself (dev-lang/bun-bin; `bun build --compile`
# embeds its runtime into the binary) and @parcel/watcher-linux-x64-glibc,
# a native npm package the build copies in from node_modules.
# The 2.x tree builds the CLI from packages/cli; the web UI
# (packages/app, vite) is built in the same step and embedded.
#
# The persistent PTY daemon (packages/process-daemon, Rust) builds here
# too: since 2.3.x its wire protocol moves with the CLI (protocol 9 at
# 2.3.2) and upstream stopped tagging the standalone opencode-pty repo,
# so building both from one tag is the only safe pairing. The CLI
# resolves `opencode-pty` on PATH at runtime (--skip-install keeps the
# prebuilt pty asset out of the binary), so the daemon installs as
# /usr/bin/opencode-pty. Upstream's build.rs clones Ghostty and runs zig
# on it for libghostty-vt.a; the patch makes it take the archive from
# dev-libs/libghostty-vt instead (same pinned revision).

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

# Dependency tarballs live as release assets on the overlay repository,
# one release per opencode version, tagged opencode-v<version>.
OPENCODE_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/opencode-v${PV}"

DESCRIPTION="The open source AI coding agent"
HOMEPAGE="https://opencode.ai https://github.com/anomalyco/opencode"
SRC_URI="
	https://github.com/anomalyco/opencode/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${OPENCODE_DISTFILES}/${P}-node_modules.tar.xz
	${CARGO_CRATE_URIS}
"
S="${WORKDIR}/opencode-${PV}"

LICENSE="MIT"
# Crates, and the libghostty-vt archive linked into the pty daemon
# (Ghostty MIT, simdutf and highway Apache-2.0).
LICENSE+=" Apache-2.0 Unicode-3.0"
# One slot per major: 1.x is /usr/bin/opencode, 2.x is /usr/bin/opencode2,
# the parallel command name upstream's 2.x package declares itself.
SLOT="2"
KEYWORDS="~amd64"
IUSE="+webui"

# The compiled binary carries Bun's runtime with an appended bundle;
# stripping would corrupt it.
RESTRICT="strip"
QA_PREBUILT="usr/bin/opencode2"

BDEPEND=">=dev-lang/bun-bin-1.4.4"

DEPEND="dev-libs/libghostty-vt"

# GURU's dev-util/opencode-bin installs the same /usr/bin/opencode, the
# retired dev-util/opencode-pty the same /usr/bin/opencode-pty.
RDEPEND="
	!dev-util/opencode-bin
	!dev-util/opencode-pty
"

src_unpack() {
	unpack "${P}.tar.gz"
	# node_modules unpacks across the workspace tree (rooted at the repo
	# top level).
	cd "${S}" || die
	unpack "${P}-node_modules.tar.xz"
	cd "${WORKDIR}" || die
	cargo_crate_unpack
	cargo_gen_config
}

src_prepare() {
	# The pty patch was written against the standalone repo whose root is
	# this package dir; build.rs is byte-identical, so it applies from here.
	pushd packages/process-daemon >/dev/null || die
	eapply "${FILESDIR}/${P}-system-ghostty-vt.patch"
	# Portage strips and keeps the debug info; cargo must not pre-empt it.
	sed -i '/^strip = "symbols"$/d' Cargo.toml || die
	if grep -q '^strip = ' Cargo.toml; then
		die "strip setting still in Cargo.toml"
	fi
	popd >/dev/null || die
	default
}

src_configure() {
	# Where the patched build.rs finds libghostty-vt.a.
	export GHOSTTY_VT_LIB_DIR="${EPREFIX}/usr/$(get_libdir)/libghostty-vt-opencode"
	cargo_src_configure
}

src_compile() {
	# The pty daemon first: protocol-matched to the CLI by construction.
	pushd packages/process-daemon >/dev/null || die
	cargo_src_compile
	popd >/dev/null || die

	# Version/channel would otherwise be probed from git, which the
	# tarball lacks. BUN_COMPILE_RELEASE stays unset: the script then
	# compiles onto the running Bun instead of downloading a release.
	local -x OPENCODE_VERSION="${PV}"
	local -x OPENCODE_CHANNEL="latest"
	# vite prints only the final asset table by default; its debug
	# loggers (the --debug flag) are enabled through this variable and
	# show module resolution as the web UI bundles.
	local -x DEBUG="vite:*"
	# Bun honours vite's `#!/usr/bin/env node` shebang and hands the web
	# UI build to a system node when one is installed, so the build ran
	# on node 26 or on Bun depending on the box. node 26's TurboFan loops
	# forever in that build on some CPUs. A node symlink to bun first in
	# PATH keeps vite on Bun's runtime, which is what `bun --bun` does.
	mkdir -p "${T}/bin" || die
	ln -snf "$(type -P bun)" "${T}/bin/node" || die
	local -x PATH="${T}/bin:${PATH}"

	# --single builds only the native target; --skip-install skips the
	# cross-libc native package install used for release packaging.
	# --skip-web-ui leaves the browser UI (packages/app, a vite build)
	# out of the binary; `opencode web` then serves nothing.
	local -a args=( --single --skip-install )
	use webui || args+=( --skip-web-ui )
	cd packages/cli || die
	bun run script/build.ts "${args[@]}" || die "bun build failed"
}

src_install() {
	# opencode2, upstream's name for the 2.x CLI beside a 1.x install.
	newbin packages/cli/dist/cli-linux-x64/bin/opencode opencode2
	dobin packages/process-daemon/target/release/opencode-pty
}
