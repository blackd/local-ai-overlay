# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI is a self-hosted, OpenAI-API-compatible AI server. This package
# builds the core server only: the HTTP API, the web UI and the
# model/backend manager. Model inference happens in backend programs
# packaged separately under the app-local-ai/ category.

EAPI=8

inherit go-module local-ai-backend systemd

# Commit hash the upstream v4.9.0 release tag points at. Embedded into the
# binary (internal.Commit) so `local-ai --version` reports the same build
# metadata as upstream's official builds.
LOCAL_AI_COMMIT="f7ad3f70eb5d8a0ddf80e08557f0d7df28cf032e"

DESCRIPTION="Self-hosted, OpenAI-compatible AI server (core, without inference backends)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	https://github.com/mudler/LocalAI/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${DISTFILES_BASE}/${P}-deps.tar.xz
	${DISTFILES_BASE}/${P}-node_modules.tar.xz
	${DISTFILES_BASE}/${P}-prebuilt.tar.xz
"
S="${WORKDIR}/LocalAI-${PV}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Backend flags do not change how the core is built; they only pull in the
# matching backend package so a plain `emerge local-ai` yields a server that
# can actually run models.
IUSE="+llama-cpp audio-cpp piper stablediffusion-ggml vibevoice-cpp"

RDEPEND="
	acct-group/local-ai
	acct-user/local-ai
"
PDEPEND="
	llama-cpp? ( app-local-ai/llama-cpp )
	audio-cpp? ( app-local-ai/audio-cpp )
	piper? ( app-local-ai/piper )
	stablediffusion-ggml? ( app-local-ai/stablediffusion-ggml )
	vibevoice-cpp? ( app-local-ai/vibevoice-cpp )
"
# go.mod declares `go 1.26.0`. nodejs[npm] builds the web UI; the UI's
# dependencies come from the node_modules tarball, not the network.
BDEPEND="
	>=dev-lang/go-1.26.0
	net-libs/nodejs[npm]
"

DOCS=( README.md )

src_unpack() {
	# ${P}-deps.tar.xz unpacks to ${WORKDIR}/go-mod — exactly where
	# go-module.eclass points GOMODCACHE, so Go finds every dependency
	# offline with no further setup.
	unpack "${P}.tar.gz" "${P}-deps.tar.xz"

	# The remaining two tarballs are rooted at the repository top level
	# (core/http/react-ui/node_modules/, pkg/grpc/proto/), so they unpack
	# inside the source tree. This layout is the contract with
	# scripts/gen-distfiles.sh.
	cd "${S}" || die
	unpack "${P}-node_modules.tar.xz"
	unpack "${P}-prebuilt.tar.xz"
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

	# All mutable state (models, runtime-installed backends, generated
	# configuration) lives here; the service files above point the server
	# at it. Backend packages symlink themselves into backends/.
	keepdir /var/lib/local-ai /var/lib/local-ai/backends /var/lib/local-ai/models
	fowners -R local-ai:local-ai /var/lib/local-ai

	einstalldocs
}

pkg_postinst() {
	elog "The LocalAI core server is installed. Inference backends are separate"
	elog "packages; you may need to emerge one or more of them for the model"
	elog "types you plan to run:"
	elog "  app-local-ai/llama-cpp            text generation (GGUF models)"
	elog "  app-local-ai/stablediffusion-ggml image generation (GGUF models)"
	elog "  app-local-ai/audio-cpp            audio models (audio.cpp engine)"
	elog "  app-local-ai/piper                text-to-speech"
	elog "  app-local-ai/vibevoice-cpp        text-to-speech (VibeVoice)"
	elog "  app-local-ai/whisper              speech-to-text (whisper.cpp)"
	elog "This package's USE flags of the same names pull them in as well."
	elog "Mutable state lives in /var/lib/local-ai."
	elog "Start via: rc-service local-ai start   (OpenRC)"
	elog "       or: systemctl start local-ai    (systemd)"
}
