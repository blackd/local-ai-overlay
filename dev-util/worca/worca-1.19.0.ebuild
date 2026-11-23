# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Worca orchestrates coding agents through a workflow graph: clarify,
# plan, implement, review, each run on its own git branch, driven from
# a web UI, the CLI or chat. The agents run on a harness CLI picked per
# run: Claude Code by default, or OpenCode 1.x (dev-util/opencode:1),
# Codex, Copilot, Cursor, Gemini, Goose or Qwen Code; none is packaged
# here except OpenCode, and mock mode runs without any. The npm tarball is
# upstream's release build (CLI, server, prebuilt UI, agents, skills),
# installed with its production dependencies from the shrinkwrap.
#
# Two optional dependencies are special: node-pty ships prebuilt addons
# for macOS and Windows only, so it is compiled here against the system
# node headers; ffmpeg-static exists to download an ffmpeg binary at
# install time and is left out, worca falls through to ffmpeg on PATH.

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )

inherit optfeature python-any-r1

# The production node_modules live as a release asset on this
# repository, tagged worca-v<version>.
WORCA_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/worca-v${PV}"

DESCRIPTION="Workflow orchestration for coding agents, each run on its own git branch"
HOMEPAGE="https://github.com/SinishaDjukic/worca-cc https://www.npmjs.com/package/@worca/app"
SRC_URI="
	https://registry.npmjs.org/@worca/app/-/app-${PV}.tgz -> ${P}.npm.tgz
	${WORCA_DISTFILES}/${P}-node_modules.tar.xz
"
S="${WORKDIR}/package"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=net-libs/nodejs-22.19
	dev-vcs/git
"
# npm for the node-pty rebuild (node-gyp ships with it), python for node-gyp.
BDEPEND="
	${PYTHON_DEPS}
	net-libs/nodejs[npm]
"

WORCA_DIR="/usr/lib/node_modules/@worca/app"

src_unpack() {
	unpack "${P}.npm.tgz"
	# The dependency tree unpacks into the package itself.
	cd "${S}" || die
	unpack "${P}-node_modules.tar.xz"
}

src_compile() {
	# node-gyp takes the headers from nodedir instead of downloading a
	# headers tarball; the install script tries the prebuilds first and
	# falls back to the rebuild, which is the Linux path.
	local -x npm_config_nodedir="${EPREFIX}/usr"
	local -x NODE_GYP_FORCE_PYTHON="${PYTHON}"
	npm --offline --no-audit --no-fund --foreground-scripts rebuild node-pty || die "node-pty build failed"
	# Keep the addon and its spawn helper, drop the objects.
	local build=node_modules/node-pty/build
	find "${build}" -mindepth 1 -maxdepth 1 ! -name Release -exec rm -r {} + || die
	find "${build}"/Release -mindepth 1 -maxdepth 1 ! -name '*.node' ! -name spawn-helper -exec rm -r {} + || die
}

src_install() {
	# The npm -g layout, by hand: npm would re-resolve the dependencies.
	dodir "${WORCA_DIR%/*}"
	cp -a "${S}" "${ED}${WORCA_DIR}" || die
	rm -r "${ED}${WORCA_DIR}"/{docker,npm-shrinkwrap.json} || die
	fperms 0755 "${WORCA_DIR}"/src/cli/worca-cc.mjs
	dosym -r "${WORCA_DIR}"/src/cli/worca-cc.mjs /usr/bin/worca
	dodoc README.md
}

pkg_postinst() {
	elog "worca ui serves http://127.0.0.1:4317 and keeps its state under"
	elog "~/.worca-cc. Real runs need a signed-in harness CLI: Claude Code by"
	elog "default (not packaged), or OpenCode 1.x found as opencode on PATH or"
	elog "through WORCA_OPENCODE_BIN; 1.18.0 refuses OpenCode 2. Mock mode"
	elog "(WORCA_MOCK=1 or the UI switch) runs the pipeline without any."
	elog
	elog "Worca has no login and answers loopback requests only. To reach it"
	elog "through a proxy: WORCA_HOST for the bind address, WORCA_ALLOWED_HOSTS"
	elog "for the names it may be called by, and an identity check, Cloudflare"
	elog "Access (WORCA_CF_ACCESS_*), a JWT issuer (WORCA_IDENTITY_ISSUER), or"
	elog "WORCA_INSECURE_NO_IDENTITY_CHECK=1 when the proxy alone is trusted."
	optfeature "running the agents on OpenCode" dev-util/opencode:1
	optfeature "the media kits (promo and deck rendering)" media-video/ffmpeg
}
