# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI voice-activity-detection backend: the Silero VAD model run
# through onnxruntime, wrapped by LocalAI's Go gRPC server (cgo binding
# github.com/streamer45/silero-vad-go). No engine tree and no bundled
# runtime: upstream's Makefile downloads Microsoft's prebuilt
# onnxruntime, this build links the system library instead (same
# system-onnxruntime policy as localai-backend/piper). The .onnx model
# itself is fetched by the server at model-install time.

EAPI=8

inherit go-module local-ai-backend

DESCRIPTION="LocalAI voice-activity-detection backend (Silero VAD, onnxruntime)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="${LOCAL_AI_GO_SRC_URI}"
S="${WORKDIR}/LocalAI-${PV}/backend/go/silero-vad"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	|| (
		sci-libs/onnxruntime
		sci-libs/onnxruntime-bin
	)
"
DEPEND="${RDEPEND}"
BDEPEND=">=dev-lang/go-1.26.0"

src_unpack() {
	local-ai-backend_go_unpack
}

src_compile() {
	# The cgo binding includes the flat onnxruntime_c_api.h and links
	# -lonnxruntime. sci-libs/onnxruntime nests headers under
	# /usr/include/onnxruntime; onnxruntime-bin installs them flat into
	# /usr/include — cover both, refuse to build blind otherwise.
	[[ -f ${ESYSROOT}/usr/include/onnxruntime/onnxruntime_c_api.h ||
		-f ${ESYSROOT}/usr/include/onnxruntime_c_api.h ]] ||
		die "onnxruntime_c_api.h not found in either known header layout"
	local -x CGO_ENABLED=1
	local -x CPATH="${ESYSROOT}/usr/include/onnxruntime${CPATH:+:${CPATH}}"
	ego build -o "${PN}" ./
}

src_install() {
	local-ai-backend_gen_run_sh "${PN}"
	local-ai-backend_install "${PN}" "${S}/${PN}"
}
