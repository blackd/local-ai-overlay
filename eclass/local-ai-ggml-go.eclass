# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: local-ai-ggml-go.eclass
# @MAINTAINER:
# Plamen K. Kosseff
# @SUPPORTED_EAPIS: 8
# @PROVIDES: local-ai-ggml local-ai-backend
# @BLURB: Build scaffolding for LocalAI's ggml-engine Go backends
# @DESCRIPTION:
# The Go family of ggml backends (whisper.cpp, stable-diffusion.cpp,
# vibevoice.cpp, ...): the engine is compiled by CMake into a single
# dlopen-able module library, and a CGO-free Go gRPC server from LocalAI's
# own Go module loads it at runtime (the library path travels through an
# engine-specific environment variable set in the package's run.sh). The
# shared acceleration flags and CMake phases come from local-ai-ggml; this
# eclass adds the Go build and the install layout. The ebuild supplies the
# engine sources (src_unpack, typically via local-ai-backend_engine_unpack)
# and the knobs documented here and in local-ai-ggml.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_LOCAL_AI_GGML_GO_ECLASS} ]]; then
_LOCAL_AI_GGML_GO_ECLASS=1

inherit go-module local-ai-ggml

# @ECLASS_VARIABLE: LOCAL_AI_ENGINE_LIB
# @REQUIRED
# @DESCRIPTION:
# File name of the compute module library the wrapper CMake project
# emits, e.g. libgowhisper.so.

local-ai-ggml-go_src_compile() {
	local-ai-ggml_src_compile

	# The gRPC server itself: a CGO-free Go binary, named after the
	# package, that dlopens the library built above (only one compute
	# variant is needed instead of upstream's four — run.sh names it).
	cd "${S}" || die
	CGO_ENABLED=0 ego build -o "${PN}" ./
}

local-ai-ggml-go_src_install() {
	local-ai-backend_install "${PN}" "${BUILD_DIR}/${LOCAL_AI_ENGINE_LIB}" "${S}/${PN}"
}

EXPORT_FUNCTIONS src_compile src_install

fi
