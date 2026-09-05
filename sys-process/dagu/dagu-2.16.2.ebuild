# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# dagu is a workflow engine / modern cron alternative: DAGs defined in
# YAML, a scheduler and a web UI in one Go binary. The React frontend is
# embedded into the binary via go:embed, so it is not optional; it is
# built with webpack from the pnpm-installed node_modules tarball (npm
# only runs the build script, pnpm itself is not needed at build time).

EAPI=8

inherit go-module systemd

# Dependency tarballs live as release assets on the overlay repository,
# one release per dagu version, tagged dagu-v<version>.
DAGU_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/dagu-v${PV}"

DESCRIPTION="Workflow engine and modern cron alternative with DAGs and a web UI"
HOMEPAGE="https://dagu.sh https://github.com/dagucloud/dagu"
SRC_URI="
	https://github.com/dagucloud/dagu/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${DAGU_DISTFILES}/${P}-deps.tar.xz
	${DAGU_DISTFILES}/${P}-ui-node_modules.tar.xz
"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	acct-group/dagu
	acct-user/dagu
"
BDEPEND="
	>=dev-lang/go-1.27
	net-libs/nodejs[npm]
"

src_compile() {
	einfo "Building the web UI"
	pushd ui >/dev/null || die
	npm run build || die "ui build failed"
	popd >/dev/null || die
	# Upstream's `make cp-assets`: the bundle is embedded via go:embed.
	cp -R ui/dist/. internal/service/frontend/assets/ || die

	# Mirrors upstream's `make bin`; BUILD_VERSION comes from git there,
	# which the tarball lacks.
	ego build -ldflags "-X 'main.version=v${PV}'" -o dagu ./cmd
}

src_install() {
	dobin dagu

	newinitd "${FILESDIR}"/dagu.initd dagu
	newconfd "${FILESDIR}"/dagu.confd dagu
	systemd_dounit "${FILESDIR}"/dagu.service

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/dagu.logrotate dagu

	# DAGU_HOME: DAG definitions, run history and per-DAG logs.
	keepdir /var/lib/dagu
	fowners dagu:dagu /var/lib/dagu
}

pkg_postinst() {
	elog "The service runs 'dagu start-all' (scheduler + web UI) as the"
	elog "dagu user with DAGU_HOME=/var/lib/dagu; the UI listens on"
	elog "127.0.0.1:8080 by default. Put DAG definitions under"
	elog "/var/lib/dagu/dags or adjust via /etc/conf.d/dagu."
}
