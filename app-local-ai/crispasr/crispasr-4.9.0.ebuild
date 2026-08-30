# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI speech backend built on CrispASR, a multi-architecture ggml
# speech engine: speech-to-text (Whisper, Parakeet, Canary, Voxtral,
# Qwen3-ASR, FunASR/Paraformer/SenseVoice, ...), text-to-speech (Qwen3-TTS,
# Orpheus, Chatterbox, Kokoro, F5-TTS, VibeVoice, ...), language
# identification, punctuation and translation — a CGO-free Go gRPC server
# dlopens the compute library built from the engine at the exact commit
# this LocalAI release pins.

EAPI=8

LOCAL_AI_ENGINE_LIB="libgocrispasr.so"
LOCAL_AI_CMAKE_TARGET="gocrispasr"
# Keep the build lean, as upstream's backend build does: no tests/examples/
# server binaries, no SDL2, and no in-engine model downloading (model
# acquisition is the LocalAI server's job; backends only get local paths).
LOCAL_AI_EXTRA_CMAKE_ARGS=(
	-DCRISPASR_BUILD_TESTS=OFF
	-DCRISPASR_BUILD_EXAMPLES=OFF
	-DCRISPASR_BUILD_SERVER=OFF
	-DCRISPASR_SDL2=OFF
	-DCRISPASR_CURL=OFF
)

inherit local-ai-ggml-go

# The CrispASR commit LocalAI v4.9.0 builds against. Source of truth:
# backend/go/crispasr/Makefile (CRISPASR_VERSION) at the upstream release
# tag; the other two are that commit's submodule gitlinks (CrispStrobe's
# ggml fork and the C2PA content-credentials signer).
CRISPASR_COMMIT="a153b09b37c90cd55cd9336fccbdf3ba7a289596"
GGML_COMMIT="5049ebb8472fdc965eb3fb72c1cb111260726186"
C2PA_COMMIT="e40329b83f16f67bb5ddc7bb13ae18de0a9376fc"

DESCRIPTION="LocalAI speech backend (CrispASR gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/CrispStrobe/CrispASR/archive/${CRISPASR_COMMIT}.tar.gz -> CrispASR-${CRISPASR_COMMIT}.tar.gz
	https://github.com/CrispStrobe/ggml/archive/${GGML_COMMIT}.tar.gz -> crispstrobe-ggml-${GGML_COMMIT}.tar.gz
	https://github.com/CrispStrobe/c2pa-audio/archive/${C2PA_COMMIT}.tar.gz -> c2pa-audio-${C2PA_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/crispasr"

KEYWORDS="~amd64"
IUSE="+ffmpeg"

# ffmpeg decode support lets the backend transcribe any audio/video
# container directly (upstream disables it only because their scratch
# container cannot ship the ffmpeg runtime).
RDEPEND+="
	ffmpeg? ( media-video/ffmpeg:= )
"
DEPEND+="
	ffmpeg? ( media-video/ffmpeg:= )
"

src_unpack() {
	local-ai-backend_go_unpack

	local subs=(
		"crispstrobe-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" ggml
		"c2pa-audio-${C2PA_COMMIT}.tar.gz" "c2pa-audio-${C2PA_COMMIT}" third_party/c2pa-audio
	)
	local-ai-backend_engine_unpack "CrispASR-${CRISPASR_COMMIT}.tar.gz" CrispASR "${subs[@]}"
}

src_prepare() {
	# CrispASR's src/CMakeLists.txt locates its vendored llama.cpp, the
	# c2pa-audio submodule, and WebRTC VAD via ${CMAKE_SOURCE_DIR}, which
	# assumes CrispASR is the top-level CMake project; under
	# add_subdirectory that resolves to the wrapper dir instead. Rewrite
	# to ${PROJECT_SOURCE_DIR}, exactly as upstream's clone recipe does.
	einfo "Rewriting CMAKE_SOURCE_DIR source references to PROJECT_SOURCE_DIR"
	sed -i -e 's#${CMAKE_SOURCE_DIR}/examples/talk-llama#${PROJECT_SOURCE_DIR}/examples/talk-llama#' -e 's#${CMAKE_SOURCE_DIR}/third_party#${PROJECT_SOURCE_DIR}/third_party#' "${S}/sources/CrispASR/src/CMakeLists.txt" || die
	grep -q 'PROJECT_SOURCE_DIR}/third_party' "${S}/sources/CrispASR/src/CMakeLists.txt" || die "source-dir rewrite did not apply"

	local-ai-ggml_src_prepare
}

src_configure() {
	LOCAL_AI_EXTRA_CMAKE_ARGS+=( -DCRISPASR_FFMPEG=$(usex ffmpeg) )
	local-ai-ggml_src_configure
}
