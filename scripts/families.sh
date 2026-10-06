#!/bin/bash
# Single source of truth for the distfiles families: which package
# directories each family's release manifests. Sourced by the release
# workflows and scripts — edit HERE when adding a family, nowhere else.
# The local-ai family covers the server and every backend without a
# family of its own; the python families manifest their single package
# (their runs also need local-ai's manifests to exist — release-localai
# orders that).
declare -A FAMILY_DIRS=(
	[localai]="www-apps/localai-server sci-ml/localai LOCALAI_BACKEND_REST"
	[rerankers]="localai-backend/rerankers"
	[speaker-recognition]="localai-backend/speaker-recognition"
	[transformers]="localai-backend/transformers"
	[python-common]="localai-backend/python-common"
	[diffusers]="localai-backend/diffusers"
	[fish-speech]="localai-backend/fish-speech"
	[opencode]="dev-util/opencode"
	[gitea-runner]="dev-util/gitea-runner"
	[zot]="app-containers/zot"
	[dagu]="sys-process/dagu"
	[ormsgpack]="dev-python/ormsgpack"
)

# Resolve a family's dirs; the LOCALAI_BACKEND_REST marker expands to every
# localai-backend package that no OTHER family owns — a new backend is
# picked up automatically, and a new python family added to the registry
# above is excluded automatically.
family_dirs() {
	local dirs="${FAMILY_DIRS[$1]:?unknown family: $1}"
	if [[ ${dirs} == *LOCALAI_BACKEND_REST* ]]; then
		local owned=" " f d rest=""
		for f in "${!FAMILY_DIRS[@]}"; do
			[[ ${f} == "$1" ]] && continue
			for d in ${FAMILY_DIRS[$f]}; do owned+="${d%/} "; done
		done
		for d in localai-backend/*/; do
			[[ ${owned} == *" ${d%/} "* ]] || rest+="${d%/} "
		done
		dirs="${dirs/LOCALAI_BACKEND_REST/${rest}}"
	fi
	echo "${dirs}"
}
