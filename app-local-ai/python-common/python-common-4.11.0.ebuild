# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# The shared python layer every LocalAI python backend imports: the
# backend/python/common helper modules and the gRPC stubs generated
# from backend/backend.proto (identical for all backends — one proto).
# Installed once in a private directory the backends put on PYTHONPATH;
# the generic module names (model_utils, grpc_auth, ...) must never
# land in site-packages.

EAPI=8

inherit local-ai-backend

PYTHON_COMMON_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/python-common-v${PV}"

DESCRIPTION="Shared python helpers and gRPC stubs for the LocalAI python backends"
SRC_URI="
	${LOCAL_AI_SRC_URI}
	${PYTHON_COMMON_DISTFILES}/python-common-${PV}-stubs.tar.xz
"
S="${WORKDIR}/LocalAI-${PV}/backend/python/common"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="sci-ml/local-ai"

src_install() {
	# The whole directory, tests and all: carrying a few inert files
	# beats re-auditing the import closure at every bump.
	insinto /usr/libexec/local-ai/python-common
	doins -r ./*
	doins "${WORKDIR}"/stubs/backend_pb2.py "${WORKDIR}"/stubs/backend_pb2_grpc.py
}
