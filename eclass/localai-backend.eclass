# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: localai-backend.eclass
# @MAINTAINER:
# Plamen K. Kosseff
# @SUPPORTED_EAPIS: 8
# @BLURB: Shared constants and helpers for LocalAI packages
# @DESCRIPTION:
# LocalAI is a self-hosted AI server whose model inference runs in separate
# backend programs. This eclass is shared by the core server package
# (sci-ml/local-ai) and every backend package (app-localai/*). It defines
# where backends install, where the maintainer-generated dependency tarballs
# are hosted, and the install helper that gives every backend the layout the
# server expects (a directory containing run.sh, discovered by scanning
# LOCALAI_BACKENDS_PATH at runtime).

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_LOCALAI_BACKEND_ECLASS} ]]; then
_LOCALAI_BACKEND_ECLASS=1

# @ECLASS_VARIABLE: DISTFILES_BASE
# @DESCRIPTION:
# Base URL of the maintainer-generated dependency tarballs (Go module cache,
# npm node_modules, pre-generated protobuf Go code). They are produced by
# scripts/gen-distfiles.sh and attached as release assets on the overlay's
# own Gitea repository: one release per LocalAI version, tagged v<version>,
# holding that version's three tarballs.
DISTFILES_BASE="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/v${PV}"

# @ECLASS_VARIABLE: LOCALAI_BACKENDS_DIR
# @DESCRIPTION:
# Install root for backend packages. /usr/libexec is the filesystem-standard
# location for internal executables that must not appear in $PATH; it is not
# split per ABI, so the path is identical on every architecture. Portage
# provides no variable for it, so this eclass is that variable.
LOCALAI_BACKENDS_DIR="${EPREFIX}/usr/libexec/local-ai/backends"

# @ECLASS_VARIABLE: LOCALAI_RUNTIME_BACKENDS_DIR
# @DESCRIPTION:
# The directory the running server actually scans (its LOCALAI_BACKENDS_PATH,
# set by the service files of sci-ml/local-ai). Backend packages symlink
# themselves in here so they appear next to backends the server installs
# itself at runtime.
LOCALAI_RUNTIME_BACKENDS_DIR="/var/lib/localai/backends"

# @FUNCTION: localai-backend_install
# @USAGE: <backend-name> <file>...
# @DESCRIPTION:
# Install <file>s into ${LOCALAI_BACKENDS_DIR}/<backend-name>/, add run.sh
# and metadata.json from FILESDIR, and create the discovery symlink in
# ${LOCALAI_RUNTIME_BACKENDS_DIR}. Executables keep their exec bits via
# doexe; run.sh is always installed executable.
localai-backend_install() {
	local name=$1; shift
	local dest="${LOCALAI_BACKENDS_DIR#${EPREFIX}}/${name}"

	exeinto "${dest}"
	doexe "$@"
	doexe "${FILESDIR}"/run.sh

	insinto "${dest}"
	doins "${FILESDIR}"/metadata.json

	dosym -r "${dest}" "${LOCALAI_RUNTIME_BACKENDS_DIR}/${name}"
}

fi
