# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# CaddyUI manages Caddy through its admin API: proxy hosts, redirects,
# certificates, Layer4 routes and a fleet of Caddy servers, from a web
# interface. Pure Go with the web assets embedded (the Tailwind CSS is
# committed prebuilt), SQLite through modernc.org/sqlite, so no cgo.
# Caddy itself is not a dependency: the admin API may be local or on
# other hosts, and several features need a Caddy built with extra
# modules (caddy-l4, Coraza), which www-servers/caddy does not carry.

EAPI=8

inherit go-module systemd

# The Go module cache lives as a release asset on this repository,
# tagged caddyui-v<version>.
CADDYUI_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/caddyui-v${PV}"

DESCRIPTION="Self-hosted web UI for Caddy: proxy hosts, certificates, routes and fleet"
HOMEPAGE="https://github.com/X4Applegate/caddyui"
SRC_URI="
	https://github.com/X4Applegate/caddyui/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${CADDYUI_DISTFILES}/${P}-deps.tar.xz
"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	acct-group/caddyui
	acct-user/caddyui
"
BDEPEND=">=dev-lang/go-1.27.3"

src_compile() {
	# Mirrors the Dockerfile's build, minus -s -w: stripping is
	# Portage's job.
	local -x CGO_ENABLED=0
	local -x GOTOOLCHAIN=local
	ego build -trimpath -ldflags "-X main.Version=v${PV}" -o caddyui ./cmd/caddyui
}

src_test() {
	# The embedded web assets, as upstream's image build checks them.
	ego test ./web/
}

src_install() {
	dobin caddyui
	einstalldocs

	newinitd "${FILESDIR}"/caddyui.initd caddyui
	newconfd "${FILESDIR}"/caddyui.confd caddyui
	systemd_dounit "${FILESDIR}"/caddyui.service

	# Database, backups and the SQLite temp dir (SQLITE_TMPDIR).
	keepdir /var/lib/caddyui
	fowners caddyui:caddyui /var/lib/caddyui
	fperms 0750 /var/lib/caddyui
}

pkg_postinst() {
	elog "CaddyUI listens on 127.0.0.1:8080 and talks to Caddy's admin API"
	elog "at http://127.0.0.1:2019; both are set in /etc/conf.d/caddyui or"
	elog "the systemd unit. The first visit creates the admin account."
}
