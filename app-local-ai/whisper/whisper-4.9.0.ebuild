# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI speech-to-text backend, built from whisper.cpp at the exact
# commit this LocalAI release pins. whisper.cpp vendors ggml in-tree, so a
# single engine tarball suffices. Upstream's Makefile passes GGML_HIPBLAS
# for ROCm, which this ggml no longer understands (silently CPU-only);
# the eclass default GGML_HIP is the correct toggle.

EAPI=8

LOCAL_AI_ENGINE_LIB="libgowhisper.so"

inherit local-ai-ggml-backend

# The whisper.cpp commit LocalAI v4.9.0 builds against. Source of truth:
# backend/go/whisper/Makefile (WHISPER_CPP_VERSION) at the upstream
# release tag.
WHISPER_COMMIT="1fe009caeda75f69bc864d6370b10674e45a92bd"

DESCRIPTION="LocalAI speech-to-text backend (whisper.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/ggml-org/whisper.cpp/archive/${WHISPER_COMMIT}.tar.gz -> whisper.cpp-${WHISPER_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/whisper"

KEYWORDS="~amd64 ~arm64"

src_unpack() {
	local-ai-backend_go_unpack
	local-ai-backend_engine_unpack "whisper.cpp-${WHISPER_COMMIT}.tar.gz" whisper.cpp
}
