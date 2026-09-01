# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# zot is an OCI-native container image registry. Pure Go, built with the
# upstream-default extension set as build tags; the optional web interface
# (the zui React app, pinned by upstream) is built from source and
# embedded into the binary.

EAPI=8

inherit go-module systemd

# The dependency tarballs live as release assets on this repository,
# tagged zot-v<version>.
ZOT_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/zot-v${PV}"

# The zui tag zot's Makefile pins (ZUI_VERSION).
ZUI_PIN="commit-a7feb46"

DESCRIPTION="OCI-native container image registry"
HOMEPAGE="https://zotregistry.dev https://github.com/project-zot/zot"
SRC_URI="
	https://github.com/project-zot/zot/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${ZOT_DISTFILES}/${P}-deps.tar.xz
	ui? (
		https://github.com/project-zot/zui/archive/refs/tags/${ZUI_PIN}.tar.gz -> zui-${ZUI_PIN}.tar.gz
		${ZOT_DISTFILES}/${P}-zui-node_modules.tar.xz
	)
"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+ui"

RDEPEND="
	acct-group/zot
	acct-user/zot
"
BDEPEND="
	>=dev-lang/go-1.26.7
	ui? ( net-libs/nodejs[npm] )
"

src_prepare() {
	default

	# The node_modules tarball unpacks at the WORKDIR top level; move it
	# into the zui tree where npm expects it.
	if use ui; then
		mv "${WORKDIR}/node_modules" "${WORKDIR}/zui-${ZUI_PIN}/node_modules" || die
	fi
}

src_compile() {
	# Upstream's default extension set (Makefile EXTENSIONS), minus/plus
	# the ui tag depending on the flag.
	local tags="sync,search,scrub,metrics,lint,mgmt,profile,userprefs,imagetrust,events"

	if use ui; then
		einfo "Building the zui web interface"
		pushd "${WORKDIR}/zui-${ZUI_PIN}" >/dev/null || die
		npm run build || die "zui build failed"
		popd >/dev/null || die
		rm -rf pkg/extensions/build
		cp -R "${WORKDIR}/zui-${ZUI_PIN}/build" pkg/extensions/build || die
		tags+=",ui"
	fi

	# Mirrors upstream's `make binary` invocation (including its
	# GOEXPERIMENT), minus -s -w: stripping is Portage's job.
	local ldflags=(
		-X "zotregistry.dev/zot/v2/pkg/buildinfo.ReleaseTag=v${PV}"
		-X "zotregistry.dev/zot/v2/pkg/buildinfo.Commit=v${PV}"
		-X "zotregistry.dev/zot/v2/pkg/buildinfo.BinaryType=-${tags//,/-}"
		-X "zotregistry.dev/zot/v2/pkg/buildinfo.GoVersion=$(go env GOVERSION)"
	)
	local -x CGO_ENABLED=0 GOEXPERIMENT=jsonv2
	ego build -tags "${tags}" -trimpath -ldflags "${ldflags[*]}" -o zot ./cmd/zot
}

src_install() {
	dobin zot

	insinto /etc/zot
	if use ui; then
		newins "${FILESDIR}"/config-ui.json config.json
	else
		doins "${FILESDIR}"/config.json
	fi

	newinitd "${FILESDIR}"/zot.initd zot
	newconfd "${FILESDIR}"/zot.confd zot
	systemd_dounit "${FILESDIR}"/zot.service

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/zot.logrotate zot

	# Image storage (storage.rootDirectory in the config).
	keepdir /var/lib/zot
	fowners zot:zot /var/lib/zot
}

pkg_postinst() {
	elog "The registry listens on 127.0.0.1:5000 and stores images under"
	elog "/var/lib/zot; adjust /etc/zot/config.json before serving other"
	elog "hosts (authentication is not configured by default)."
}
