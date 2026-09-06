# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-to-speech backend for Qwen3-TTS models, built from
# ServeurpersoCom's qwentts.cpp at the exact commit this LocalAI release
# pins. Upstream HOLDS this pin back deliberately: 35ebe537 is the last
# commit before a synthesis hang (qwentts.cpp 26dd8adb, LocalAI #11241)
# — do not advance it past the LocalAI Makefile's pin.

EAPI=8

LOCAL_AI_ENGINE_LIB="libgoqwen3ttscpp.so"
LOCAL_AI_CMAKE_TARGET="goqwen3ttscpp"

inherit local-ai-ggml-go

# The qwentts.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/go/qwen3-tts-cpp/Makefile (QWEN3TTS_CPP_VERSION) at the
# upstream release tag; the ggml pin is that commit's root-level ggml
# gitlink (ServeurpersoCom's own ggml fork, mounted at ggml/ rather
# than third_party/).
QWEN3TTS_COMMIT="35ebe5376b82a0a59d008586d55bbe623d449011"
GGML_COMMIT="c044c6f03892f9d5e98213b05f8afea1f8b0d3c9"

DESCRIPTION="LocalAI text-to-speech backend (qwentts.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/ServeurpersoCom/qwentts.cpp/archive/${QWEN3TTS_COMMIT}.tar.gz -> qwentts.cpp-${QWEN3TTS_COMMIT}.tar.gz
	https://github.com/ServeurpersoCom/ggml/archive/${GGML_COMMIT}.tar.gz -> ServeurpersoCom-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/qwen3-tts-cpp"

KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "ServeurpersoCom-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" ggml )
	local-ai-backend_engine_unpack "qwentts.cpp-${QWEN3TTS_COMMIT}.tar.gz" qwentts.cpp "${ggml[@]}"
}
