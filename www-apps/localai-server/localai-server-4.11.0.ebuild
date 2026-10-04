# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI is a self-hosted, OpenAI-API-compatible AI server. This package
# builds the core server only: the HTTP API, the web UI and the
# model/backend manager. Model inference happens in backend programs
# packaged separately under the localai-backend/ category.

EAPI=8

inherit check-reqs go-module local-ai-backend systemd

CHECKREQS_DISK_BUILD="6500M"

pkg_pretend() {
	check-reqs_pkg_pretend
}

pkg_setup() {
	check-reqs_pkg_setup
}

# Commit hash the upstream release tag points at. Embedded into the
# binary (internal.Commit) so `local-ai --version` reports the same build
# metadata as upstream's official builds.
LOCAL_AI_COMMIT="58830f7ac508845a6f4efa32cfca06af422d4d82"

DESCRIPTION="Self-hosted, OpenAI-compatible AI server (core, without inference backends)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
# The localai-${PV} distfiles are the shared LocalAI source-release
# artifacts: the tree, -deps and -prebuilt also feed every Go backend
# (LOCAL_AI_GO_SRC_URI); only -node_modules is server-specific.
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	${DISTFILES_BASE}/${P}-node_modules.tar.xz
"
S="${WORKDIR}/LocalAI-${PV}"

PATCHES=(
	# OCI downloads stage beside the destination, not tmpfs /tmp —
	# PR #12280, open; see the patch header.
	"${FILESDIR}/localai-4.11.0-oci-staging-dir.patch"
	# Manual model imports with remote assets download through the
	# gallery job queue — PR pending; see the patch header.
	"${FILESDIR}/localai-4.11.0-manual-import-job-queue.patch"
)

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	acct-group/local-ai
	acct-user/local-ai
	!<sci-ml/localai-4.11.0
"
# go.mod declares `go 1.26.0`. nodejs[npm] builds the web UI; the UI's
# dependencies come from the node_modules tarball, not the network.
BDEPEND="
	>=dev-lang/go-1.26.0
	net-libs/nodejs[npm]
"

DOCS=( README.md )

src_unpack() {
	local-ai-backend_go_unpack
	# node_modules is rooted at the repository top level
	# (core/http/react-ui/node_modules/), so it unpacks inside the tree.
	cd "${S}" || die
	unpack "${P}-node_modules.tar.xz"
}

src_compile() {
	# Step 1: the web UI (React). Runs vite from the unpacked
	# node_modules, fully offline. The output (dist/) is embedded into
	# the Go binary at compile time (go:embed).
	pushd core/http/react-ui >/dev/null || die
	npm run build || die "web UI build failed"
	popd >/dev/null || die

	# Step 2: the server. Upstream's `make build` is bypassed on purpose:
	# it downloads Go tools and regenerates protobuf code, which the
	# network sandbox forbids; those generated files came from the
	# -prebuilt tarball. The Go module cache unpacked by the eclass
	# covers every dependency offline.
	local ldflags=(
		-s -w
		-X "github.com/mudler/LocalAI/internal.Version=v${PV}"
		-X "github.com/mudler/LocalAI/internal.Commit=${LOCAL_AI_COMMIT}"
	)
	ego build -ldflags "${ldflags[*]}" -o local-ai ./cmd/local-ai
}

src_install() {
	dobin local-ai

	newinitd "${FILESDIR}"/local-ai.initd local-ai
	newconfd "${FILESDIR}"/local-ai.confd local-ai
	systemd_dounit "${FILESDIR}"/local-ai.service

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/local-ai.logrotate local-ai

	# All mutable state (models, runtime-installed backends, generated
	# configuration) lives here; the service files above point the server
	# at it. Portage-installed backends live under /usr/libexec instead,
	# discovered via LOCALAI_BACKENDS_SYSTEM_PATH from the conf.d file.
	keepdir /var/lib/local-ai /var/lib/local-ai/backends /var/lib/local-ai/models
	fowners -R local-ai:local-ai /var/lib/local-ai

	einstalldocs
}

pkg_postinst() {
	elog "The LocalAI core server is installed. Inference backends are separate"
	elog "packages — see the localai-backend category (llama-cpp for text"
	elog "generation, stablediffusion-ggml for images, whisper for"
	elog "speech-to-text, and more). Install sci-ml/localai and set its USE"
	elog "flags to select which ones are installed; it pulls this server, so"
	elog "it is the one package to keep in world for a full stack."
	elog "Models needing a backend that is not installed through Portage make"
	elog "the server download upstream's prebuilt binary variant into"
	elog "/var/lib/local-ai/backends instead."
	elog "Mutable state lives in /var/lib/local-ai."
	elog "Start via: rc-service local-ai start   (OpenRC)"
	elog "       or: systemctl start local-ai    (systemd)"
}
