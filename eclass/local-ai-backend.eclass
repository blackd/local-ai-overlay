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

# @ECLASS_VARIABLE: LOCAL_AI_SRC_URI
# @DESCRIPTION:
# SRC_URI fragment fetching the LocalAI source tree at this version.
LOCAL_AI_SRC_URI="https://github.com/mudler/LocalAI/archive/refs/tags/v${PV}.tar.gz -> local-ai-${PV}.tar.gz"

# @ECLASS_VARIABLE: LOCAL_AI_GO_SRC_URI
# @DESCRIPTION:
# SRC_URI fragment for backends compiled from LocalAI's Go module: the
# source tree plus the Go module cache (-deps) and the pre-generated
# protobuf Go code (-prebuilt) that module needs to build offline.
LOCAL_AI_GO_SRC_URI="
	${LOCAL_AI_SRC_URI}
	${DISTFILES_BASE}/local-ai-${PV}-deps.tar.xz
	${DISTFILES_BASE}/local-ai-${PV}-prebuilt.tar.xz
"

# @FUNCTION: local-ai-backend_go_unpack
# @DESCRIPTION:
# Unpack what LOCAL_AI_GO_SRC_URI fetches: the LocalAI tree, the Go module
# cache (to ${WORKDIR}/go-mod, where go-module.eclass points GOMODCACHE),
# and the prebuilt pkg/grpc/proto package into the tree. Returns with
# ${WORKDIR} as the working directory; engine sources stay the ebuild's
# job.
local-ai-backend_go_unpack() {
	unpack "local-ai-${PV}.tar.gz" "local-ai-${PV}-deps.tar.xz"
	cd "${WORKDIR}/LocalAI-${PV}" || die
	unpack "local-ai-${PV}-prebuilt.tar.xz"
	cd "${WORKDIR}" || die
}

# @FUNCTION: local-ai-backend_engine_unpack
# @USAGE: <engine-tarball> <engine-name> [<sub-tarball> <sub-dir> <sub-path>]...
# @DESCRIPTION:
# Unpack a backend's engine tarball to ${S}/sources/<engine-name>, then any
# number of submodule triples: unpack <sub-tarball>, drop the empty
# placeholder directory the engine archive carries at <sub-path> (relative
# to the engine root; GitHub archives omit submodule content but keep the
# directory), and move the extracted <sub-dir> there. The engine archive is
# assumed to extract to its tarball name minus .tar.gz (true for GitHub
# commit archives); submodule distfiles are often renamed against
# collisions (e.g. leejet-ggml-*.tar.gz extracting to ggml-*), hence the
# explicit extracted-directory argument.
local-ai-backend_engine_unpack() {
	local engine_tarball=$1 engine_name=$2; shift 2
	local engine_root="${S}/sources/${engine_name}"

	cd "${WORKDIR}" || die
	unpack "${engine_tarball}"
	mkdir -p "${S}/sources" || die
	mv "${engine_tarball%.tar.gz}" "${engine_root}" || die

	while [[ $# -gt 0 ]]; do
		unpack "$1"
		rmdir "${engine_root}/$3" 2>/dev/null
		mv "$2" "${engine_root}/$3" || die
		shift 3
	done
}

# @FUNCTION: local-ai-backend_bump_cxx20
# @USAGE: <file>...
# @DESCRIPTION:
# Rewrite CMAKE_CXX_STANDARD 17 to 20 in the given files. System abseil is
# built for C++20 — its installed headers force std::*_ordering, and it
# exports cxx_std_20 as an INTERFACE compile feature that propagates to
# everything linking it — so C++ sources built against the system
# gRPC/absl/protobuf stack must compile as C++20; upstream's C++17
# settings only work against its vendored, C++17-configured stack.
local-ai-backend_bump_cxx20() {
	local f
	for f in "$@"; do
		einfo "Bumping C++ standard to 20 in ${f#./}"
		sed -i 's/CMAKE_CXX_STANDARD 17/CMAKE_CXX_STANDARD 20/g' "${f}" || die
		if grep -q 'CMAKE_CXX_STANDARD 17' "${f}"; then
			die "C++17 pin remains in ${f}"
		fi
	done
}

# @ECLASS_VARIABLE: LOCAL_AI_BACKENDS_DIR
# @DESCRIPTION:
# Install root for backend packages. /usr/libexec is the filesystem-standard
# location for internal executables that must not appear in $PATH; it is not
# split per ABI, so the path is identical on every architecture. Portage
# provides no variable for it, so this eclass is that variable.
LOCAL_AI_BACKENDS_DIR="${EPREFIX}/usr/libexec/local-ai/backends"

# @FUNCTION: local-ai-backend_install_meta
# @USAGE: <backend-name>
# @DESCRIPTION:
# Install the pieces every backend directory needs for discovery: run.sh
# from FILESDIR and a generated metadata.json naming the backend.
local-ai-backend_install_meta() {
	local name=$1
	local dest="${LOCAL_AI_BACKENDS_DIR#${EPREFIX}}/${name}"

	exeinto "${dest}"
	doexe "${FILESDIR}"/run.sh

	printf '{\n\t"name": "%s"\n}\n' "${name}" > "${T}"/metadata.json || die
	insinto "${dest}"
	doins "${T}"/metadata.json
}

# @FUNCTION: local-ai-backend_install
# @USAGE: <backend-name> <file>...
# @DESCRIPTION:
# Install <file>s into ${LOCAL_AI_BACKENDS_DIR}/<backend-name>/ together
# with run.sh and metadata.json. The server discovers this directory via
# LOCALAI_BACKENDS_SYSTEM_PATH (set in sci-ml/local-ai's service config);
# symlinking into /var/lib is neither needed nor seen by discovery, which
# skips symlinked entries.
local-ai-backend_install() {
	local name=$1; shift
	local dest="${LOCAL_AI_BACKENDS_DIR#${EPREFIX}}/${name}"

	exeinto "${dest}"
	doexe "$@"

	local-ai-backend_install_meta "${name}"
}

fi
