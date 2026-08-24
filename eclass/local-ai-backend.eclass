# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: local-ai-backend.eclass
# @MAINTAINER:
# Plamen K. Kosseff
# @SUPPORTED_EAPIS: 8
# @BLURB: Shared constants and helpers for LocalAI packages
# @DESCRIPTION:
# LocalAI is a self-hosted AI server whose model inference runs in separate
# backend programs. This eclass is shared by the core server package
# (sci-ml/local-ai) and every backend package (app-local-ai/*). It defines
# where backends install, where the maintainer-generated dependency tarballs
# are hosted, and the install helper that gives every backend the layout the
# server expects (a directory containing run.sh, discovered by scanning
# LOCALAI_BACKENDS_SYSTEM_PATH at runtime).

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_LOCAL_AI_BACKEND_ECLASS} ]]; then
_LOCAL_AI_BACKEND_ECLASS=1

# @ECLASS_VARIABLE: DISTFILES_BASE
# @DESCRIPTION:
# Base URL of the maintainer-generated dependency tarballs (Go module cache,
# npm node_modules, pre-generated protobuf Go code). They are produced by
# scripts/gen-distfiles.sh and attached as release assets on the overlay's
# own Gitea repository: one release per LocalAI version, tagged v<version>,
# holding that version's three tarballs.
DISTFILES_BASE="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/v${PV}"

# @ECLASS_VARIABLE: LOCAL_AI_BACKENDS_DIR
# @DESCRIPTION:
# Install root for backend packages. /usr/libexec is the filesystem-standard
# location for internal executables that must not appear in $PATH; it is not
# split per ABI, so the path is identical on every architecture. Portage
# provides no variable for it, so this eclass is that variable.
LOCAL_AI_BACKENDS_DIR="${EPREFIX}/usr/libexec/local-ai/backends"

# @FUNCTION: local-ai-backend_install
# @USAGE: <backend-name> <file>...
# @DESCRIPTION:
# Install <file>s into ${LOCAL_AI_BACKENDS_DIR}/<backend-name>/, add run.sh
# and metadata.json from FILESDIR. The server discovers this directory via
# LOCALAI_BACKENDS_SYSTEM_PATH (set in sci-ml/local-ai's service config);
# symlinking into /var/lib is neither needed nor seen by discovery, which
# skips symlinked entries.
local-ai-backend_install() {
	local name=$1; shift
	local dest="${LOCAL_AI_BACKENDS_DIR#${EPREFIX}}/${name}"

	exeinto "${dest}"
	doexe "$@"
	doexe "${FILESDIR}"/run.sh

	insinto "${dest}"
	doins "${FILESDIR}"/metadata.json
}

fi
