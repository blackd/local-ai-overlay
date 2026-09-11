# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: local-ai-python.eclass
# @MAINTAINER:
# Plamen K. Kosseff
# @SUPPORTED_EAPIS: 8
# @PROVIDES: local-ai-backend python-single-r1
# @BLURB: Shared venv assembly for LocalAI python backends
# @DESCRIPTION:
# LocalAI's python backends (diffusers, fish-speech, ...) share one
# skeleton: a venv assembled OFFLINE in src_install from a wheels
# release asset, with --system-site-packages exposing every
# tree-provided package — torch included — as a real Portage package
# (the parity rule: the venv ships everything upstream's install
# resolves, minus what the tree provides). Shared helpers and gRPC
# stubs come from app-local-ai/python-common via run.sh's PYTHONPATH.
#
# The eclass provides the wheels SRC_URI (release family = ${PN}),
# the common dependency baseline (torch, the tokenizer/safetensors
# pair, gRPC, and the huggingface-hub HTTP stack every backend's
# resolution contains), the no-op src_compile, a generated run.sh,
# and the src_install venv dance ending in the build-time import
# smoke test. Backends with extra sources or install steps override
# the phase and compose the helpers (see app-local-ai/fish-speech).

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_LOCAL_AI_PYTHON_ECLASS} ]]; then
_LOCAL_AI_PYTHON_ECLASS=1

PYTHON_COMPAT=( python3_{12..14} )

inherit local-ai-backend python-single-r1

# @ECLASS_VARIABLE: LOCAL_AI_PYTHON_EXES
# @DESCRIPTION:
# Executables (relative to ${S}) installed into the backend dir.
: "${LOCAL_AI_PYTHON_EXES:=backend.py}"

# @ECLASS_VARIABLE: LOCAL_AI_PYTHON_SMOKE_IMPORTS
# @DESCRIPTION:
# Space-separated modules the build-time smoke test imports. List the
# real inference entry modules when backend.py imports its engine
# lazily — importing "backend" alone proves nothing then.
: "${LOCAL_AI_PYTHON_SMOKE_IMPORTS:=backend}"

LOCAL_AI_PYTHON_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/${PN}-v${PV}"

SRC_URI="
	${LOCAL_AI_SRC_URI}
	${LOCAL_AI_PYTHON_DISTFILES}/${PN}-${PV}-wheels.tar.xz
"
S="${WORKDIR}/LocalAI-${PV}/backend/python/${PN}"

SLOT="0"
KEYWORDS="~amd64"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

BACKEND_DIR="/usr/libexec/local-ai/backends/${PN}"

# The baseline every python backend's resolution contains: torch, the
# HF tokenizer/safetensors pair, gRPC + protobuf for the wire, and the
# huggingface-hub HTTP stack. Backend-specific tree deps go in the
# ebuild's own RDEPEND.
RDEPEND="${PYTHON_DEPS}
	sci-ml/local-ai
	~app-local-ai/python-common-${PV}
	$(python_gen_cond_dep '
		sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]
		dev-python/safetensors[${PYTHON_USEDEP}]
		dev-python/tokenizers[${PYTHON_USEDEP}]
		>=dev-python/grpcio-1.76.0[${PYTHON_USEDEP}]
		dev-python/protobuf[${PYTHON_USEDEP}]
		dev-python/anyio[${PYTHON_USEDEP}]
		dev-python/certifi[${PYTHON_USEDEP}]
		dev-python/charset-normalizer[${PYTHON_USEDEP}]
		dev-python/filelock[${PYTHON_USEDEP}]
		dev-python/fsspec[${PYTHON_USEDEP}]
		dev-python/h11[${PYTHON_USEDEP}]
		dev-python/httpcore[${PYTHON_USEDEP}]
		dev-python/httpx[${PYTHON_USEDEP}]
		dev-python/idna[${PYTHON_USEDEP}]
		dev-python/importlib-metadata[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/packaging[${PYTHON_USEDEP}]
		dev-python/psutil[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/regex[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
		dev-python/tqdm[${PYTHON_USEDEP}]
		dev-python/typing-extensions[${PYTHON_USEDEP}]
		dev-python/urllib3[${PYTHON_USEDEP}]
		dev-python/zipp[${PYTHON_USEDEP}]
	')
"
# Build-time too: the smoke test runs the backend's import closure.
DEPEND="${RDEPEND}"

local-ai-python_src_unpack() {
	unpack "local-ai-${PV}.tar.gz" "${PN}-${PV}-wheels.tar.xz"
}

local-ai-python_src_compile() {
	# The Makefile in the backend dir drives upstream's uv-based image
	# install, which the offline venv assembled in src_install
	# replaces entirely.
	:
}

# @FUNCTION: local-ai-python_install_venv
# @DESCRIPTION:
# The offline venv: system-site for every tree package, the wheels
# tarball for the pure-python layer.
local-ai-python_install_venv() {
	"${EPYTHON}" -m venv --system-site-packages "${ED}${BACKEND_DIR}/venv" || die
	"${ED}${BACKEND_DIR}/venv/bin/python" -m pip install \
		--no-index --find-links "${WORKDIR}/wheels" --no-deps --no-compile \
		"${WORKDIR}"/wheels/*.whl || die
	# The venv's paths must not remember the image root.
	find "${ED}${BACKEND_DIR}/venv/bin" -type f -exec sed -i "s:${D}::g" {} + || die
	python_optimize "${ED}${BACKEND_DIR}/venv/lib"
}

# @FUNCTION: local-ai-python_install_meta
# @DESCRIPTION:
# run.sh (generated — identical for every python backend) and the
# discovery metadata.json.
local-ai-python_install_meta() {
	cat > "${T}/run.sh" <<-EOF || die
	#!/bin/sh
	# Entry point the LocalAI server invokes to start this backend.
	CURDIR=\$(dirname "\$(readlink -f "\$0")")
	# Shared helpers and gRPC stubs from app-local-ai/python-common.
	PYTHONPATH="/usr/libexec/local-ai/python-common\${PYTHONPATH:+:\${PYTHONPATH}}"
	export PYTHONPATH
	exec "\${CURDIR}/venv/bin/python" "\${CURDIR}/backend.py" "\$@"
	EOF
	exeinto "${BACKEND_DIR}"
	doexe "${T}/run.sh"

	printf '{\n\t"name": "%s"\n}\n' "${PN}" > "${T}"/metadata.json || die
	insinto "${BACKEND_DIR}"
	doins "${T}"/metadata.json
}

# @FUNCTION: local-ai-python_smoke_test
# @DESCRIPTION:
# The whole import closure must resolve NOW, at build time — not at
# the user's first model load.
local-ai-python_smoke_test() {
	PYTHONPATH="${ED}${BACKEND_DIR}:${EPREFIX}/usr/libexec/local-ai/python-common" \
		"${ED}${BACKEND_DIR}/venv/bin/python" -c \
		"$(printf 'import %s\n' ${LOCAL_AI_PYTHON_SMOKE_IMPORTS})" \
		|| die "backend import check failed"
}

local-ai-python_src_install() {
	exeinto "${BACKEND_DIR}"
	doexe ${LOCAL_AI_PYTHON_EXES}
	local-ai-python_install_venv
	local-ai-python_install_meta
	local-ai-python_smoke_test
}

EXPORT_FUNCTIONS src_unpack src_compile src_install

fi
