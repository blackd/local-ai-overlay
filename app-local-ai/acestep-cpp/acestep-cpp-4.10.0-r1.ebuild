# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI music-generation backend: text-to-music with ACE-Step models,
# built from acestep.cpp at the exact commit this LocalAI release pins.
# The engine compiles into a dlopen-able module library loaded by a
# CGO-free Go gRPC server from LocalAI's own Go module (the ggml-go
# backend family layout).

EAPI=8

LOCAL_AI_ENGINE_LIB="libgoacestepcpp.so"
LOCAL_AI_ENGINE_LIB_ENV="ACESTEP_LIBRARY"

inherit local-ai-ggml-go

# The acestep.cpp commit LocalAI v4.10.0 builds against. Source of truth:
# backend/go/acestep-cpp/Makefile (ACESTEP_CPP_VERSION) at the upstream
# release tag; the ggml pin is that commit's submodule gitlink
# (ServeurpersoCom's ggml fork).
ACESTEP_COMMIT="ed53caf164e4492a5620b2e3f2264629cf66da24"
GGML_COMMIT="f3bc6505c4e2ede83a193e0fb4695938ff3804fd"

DESCRIPTION="LocalAI music-generation backend (acestep.cpp gRPC server)"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/ace-step/acestep.cpp/archive/${ACESTEP_COMMIT}.tar.gz -> acestep.cpp-${ACESTEP_COMMIT}.tar.gz
	https://github.com/ServeurpersoCom/ggml/archive/${GGML_COMMIT}.tar.gz -> serveurperso-ggml-${GGML_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/acestep-cpp"

KEYWORDS="~amd64"

src_unpack() {
	local-ai-backend_go_unpack

	local ggml=( "serveurperso-ggml-${GGML_COMMIT}.tar.gz" "ggml-${GGML_COMMIT}" ggml )
	local-ai-backend_engine_unpack "acestep.cpp-${ACESTEP_COMMIT}.tar.gz" acestep.cpp "${ggml[@]}"
}
