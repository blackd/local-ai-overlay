# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# opencode is an AI coding agent (terminal UI + web UI) written in
# TypeScript and compiled with Bun into a single self-contained binary.
# Bun itself is the one prebuilt component (dev-lang/bun-bin): building the
# Bun toolchain from source is not practical, and `bun build --compile`
# embeds the Bun runtime into the produced binary.

EAPI=8

# Dependency tarballs live as release assets on the overlay repository,
# one release per opencode version, tagged opencode-v<version>.
OPENCODE_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/opencode-v${PV}"

DESCRIPTION="The open source AI coding agent"
HOMEPAGE="https://opencode.ai https://github.com/anomalyco/opencode"
SRC_URI="
	https://github.com/anomalyco/opencode/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${OPENCODE_DISTFILES}/${P}-node_modules.tar.xz
	${OPENCODE_DISTFILES}/${P}-models.json.xz
"
S="${WORKDIR}/opencode-${PV}"

LICENSE="MIT"
# One slot per major: 1.x is /usr/bin/opencode, 2.x is /usr/bin/opencode2,
# the parallel command name upstream's 2.x package declares itself.
SLOT="1"
KEYWORDS="~amd64"

# The compiled binary carries Bun's runtime with an appended bundle;
# stripping would corrupt it.
RESTRICT="strip"
QA_PREBUILT="usr/bin/opencode"

BDEPEND=">=dev-lang/bun-bin-1.4.4"

# GURU's dev-util/opencode-bin installs the same /usr/bin/opencode.
RDEPEND="!dev-util/opencode-bin"

src_unpack() {
	unpack "${P}.tar.gz"
	# node_modules unpacks across the workspace tree (rooted at the repo
	# top level); the models.dev snapshot lands next to it in WORKDIR.
	cd "${S}" || die
	unpack "${P}-node_modules.tar.xz"
	cd "${WORKDIR}" || die
	unpack "${P}-models.json.xz"
}

src_compile() {
	# Version/channel would otherwise be probed from git, which the
	# tarball lacks; the models.dev snapshot replaces a build-time fetch.
	local -x OPENCODE_VERSION="${PV}"
	local -x OPENCODE_CHANNEL="latest"
	local -x MODELS_DEV_API_JSON="${WORKDIR}/${P}-models.json"
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
	# cross-platform artifact downloads used for release packaging.
	cd packages/opencode || die
	bun run script/build.ts --single --skip-install || die "bun build failed"
}

src_install() {
	dobin packages/opencode/dist/opencode-linux-x64/bin/opencode
}
