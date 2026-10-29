# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# opencode is an AI coding agent (terminal UI + web UI) written in
# TypeScript and compiled with Bun into a single self-contained binary.
# Prebuilt components: Bun itself (dev-lang/bun-bin; `bun build --compile`
# embeds its runtime into the binary) and @parcel/watcher-linux-x64-glibc,
# a native npm package the build copies in from node_modules. The
# opencode-pty helper the binary embeds comes from dev-util/opencode-pty
# through OPENCODE_PTY_BIN, not from the prebuilt npm package.
# The 2.x tree builds the CLI from packages/cli; the web UI
# (packages/app, vite) is built in the same step and embedded, and the
# models.dev catalog comes from the snapshot committed in packages/core.

EAPI=8

# Dependency tarballs live as release assets on the overlay repository,
# one release per opencode version, tagged opencode-v<version>.
OPENCODE_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/opencode-v${PV}"

DESCRIPTION="The open source AI coding agent"
HOMEPAGE="https://opencode.ai https://github.com/anomalyco/opencode"
SRC_URI="
	https://github.com/anomalyco/opencode/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${OPENCODE_DISTFILES}/${P}-node_modules.tar.xz
"
S="${WORKDIR}/opencode-${PV}"

LICENSE="MIT"
# One slot per major: 1.x is /usr/bin/opencode, 2.x is /usr/bin/opencode2,
# the parallel command name upstream's 2.x package declares itself.
SLOT="2"
KEYWORDS="~amd64"
IUSE="+webui"

# The compiled binary carries Bun's runtime with an appended bundle;
# stripping would corrupt it.
RESTRICT="strip"
QA_PREBUILT="usr/bin/opencode2"

BDEPEND="
	>=dev-lang/bun-bin-1.4.4
	dev-util/opencode-pty
"

# GURU's dev-util/opencode-bin installs the same /usr/bin/opencode.
RDEPEND="!dev-util/opencode-bin"

src_unpack() {
	unpack "${P}.tar.gz"
	# node_modules unpacks across the workspace tree (rooted at the repo
	# top level).
	cd "${S}" || die
	unpack "${P}-node_modules.tar.xz"
}

src_compile() {
	# Version/channel would otherwise be probed from git, which the
	# tarball lacks. BUN_COMPILE_RELEASE stays unset: the script then
	# compiles onto the running Bun instead of downloading a release.
	local -x OPENCODE_VERSION="${PV}"
	local -x OPENCODE_CHANNEL="latest"
	# Embed the system opencode-pty instead of the @opencode-ai/pty wheel.
	local -x OPENCODE_PTY_BIN="${EPREFIX}/usr/bin/opencode-pty"

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
}
