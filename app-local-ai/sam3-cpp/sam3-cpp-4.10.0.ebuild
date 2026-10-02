# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI image-segmentation backend: Meta's SAM 3 (Segment Anything)
# via sam3.cpp, built from the exact commit this LocalAI release pins.
# The engine compiles into a dlopen-able module library loaded by a
# CGO-free Go gRPC server from LocalAI's own Go module (the ggml-go
# backend family layout).

EAPI=8

LOCAL_AI_ENGINE_LIB="libgosam3.so"
LOCAL_AI_ENGINE_LIB_ENV="SAM3_LIBRARY"

inherit local-ai-ggml-go

# The sam3.cpp commit LocalAI v4.10.0 builds against. Source of truth:
# backend/go/sam3-cpp/Makefile (SAM3_VERSION) at the upstream release
# tag; the ggml pin is that commit's submodule gitlink (PABannier's
# ggml fork).
SAM3_COMMIT="416186c501d060df7ca02989d49b38080f5f81f3"
GGML_COMMIT="331b9cba52b23d895bc4ad218c007eb5e667540f"

DESCRIPTION="LocalAI image-segmentation backend (sam3.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/PABannier/sam3.cpp/archive/${SAM3_COMMIT}.tar.gz -> sam3.cpp-${SAM3_COMMIT}.tar.gz
	https://github.com/PABannier/ggml/archive/${GGML_COMMIT}.tar.gz -> pabannier-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/sam3-cpp"

KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "pabannier-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" ggml )
	local-ai-backend_engine_unpack "sam3.cpp-${SAM3_COMMIT}.tar.gz" sam3.cpp "${ggml[@]}"
}
