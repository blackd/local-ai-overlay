# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# zot is an OCI-native container image registry. Pure Go, built with the
# upstream-default extension set as build tags; the optional web interface
# (the zui React app, pinned by upstream) is built from source and
# embedded into the binary.

EAPI=8

inherit check-reqs go-module systemd

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

CHECKREQS_DISK_BUILD="10G"

pkg_pretend() {
	check-reqs_pkg_pretend
}

pkg_setup() {
	check-reqs_pkg_setup
}

src_prepare() {
	default

	# The node_modules tarball unpacks at the WORKDIR top level; move it
	# into the zui tree where npm expects it.
	if use ui; then
		mv "${WORKDIR}/node_modules" "${WORKDIR}/zui-${ZUI_PIN}/node_modules" || die
	fi

	# trivy v0.72.0 uses the experimental json/v2 SkipFunc sentinel,
	# which go 1.27's graduated encoding/json/v2 removed; upstream fix
	# is aquasecurity/trivy@dc3c56ee (not yet in any zot release) and
	# replaces it with errors.ErrUnsupported. Apply the same change to
	# every affected file in the module cache copy (extracted trees are
	# not re-verified against go.sum).
	if has_version -b ">=dev-lang/go-1.27"; then
		local trivy="${WORKDIR}/go-mod/github.com/aquasecurity/trivy@v0.72.0" f found=
		while IFS= read -r -d '' f; do
			found=1
			chmod u+w "${f%/*}" "${f}" || die
			sed -i -e 's:json\.SkipFunc:errors.ErrUnsupported:g' "${f}" || die
			grep -q '"errors"' "${f}" || \
				sed -i -e '0,/^import (/s:^import (:import (\n\t"errors":' "${f}" || die
		done < <(grep -rlZ 'json\.SkipFunc' "${trivy}")
		[[ -n ${found} ]] || die "trivy json/v2 fix did not apply"
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

	# Mirrors upstream's `make binary` invocation, minus -s -w: stripping
	# is Portage's job. zot targets go 1.27's encoding/json/v2 — still an
	# experiment on go 1.26, graduated (and an unknown flag) on 1.27+.
	local ldflags=(
		-X "zotregistry.dev/zot/v2/pkg/buildinfo.ReleaseTag=v${PV}"
		-X "zotregistry.dev/zot/v2/pkg/buildinfo.Commit=v${PV}"
		-X "zotregistry.dev/zot/v2/pkg/buildinfo.BinaryType=-${tags//,/-}"
		-X "zotregistry.dev/zot/v2/pkg/buildinfo.GoVersion=$(go env GOVERSION)"
	)
	local -x CGO_ENABLED=0
	if ! has_version -b ">=dev-lang/go-1.27"; then
		local -x GOEXPERIMENT=jsonv2
	fi
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
