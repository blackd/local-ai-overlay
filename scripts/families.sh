#!/bin/bash
# Single source of truth for the distfiles families: which package
# directories each family's release manifests. Sourced by the release
# workflows and scripts — edit HERE when adding a family, nowhere else.
# The local-ai family covers the server and every backend without a
# family of its own; the python families manifest their single package
# (their runs also need local-ai's manifests to exist — release-localai
# orders that).
declare -A FAMILY_DIRS=(
	[local-ai]="sci-ml/local-ai APP_LOCAL_AI_REST"
	[python-common]="app-local-ai/python-common"
	[diffusers]="app-local-ai/diffusers"
	[fish-speech]="app-local-ai/fish-speech"
	[opencode]="dev-util/opencode"
	[gitea-runner]="dev-util/gitea-runner"
	[zot]="app-containers/zot"
	[dagu]="sys-process/dagu"
	[safetensors]="dev-python/safetensors"
	[tokenizers]="dev-python/tokenizers"
	[ormsgpack]="dev-python/ormsgpack"
	[hf-xet]="dev-python/hf-xet"
)

# Resolve a family's dirs; the APP_LOCAL_AI_REST marker expands to every
# app-local-ai package that no OTHER family owns — a new backend is
# picked up automatically, and a new python family added to the registry
# above is excluded automatically.
family_dirs() {
	local dirs="${FAMILY_DIRS[$1]:?unknown family: $1}"
	if [[ ${dirs} == *APP_LOCAL_AI_REST* ]]; then
		local owned=" " f d rest=""
		for f in "${!FAMILY_DIRS[@]}"; do
			[[ ${f} == "$1" ]] && continue
			for d in ${FAMILY_DIRS[$f]}; do owned+="${d%/} "; done
		done
		for d in app-local-ai/*/; do
			[[ ${owned} == *" ${d%/} "* ]] || rest+="${d%/} "
		done
		dirs="${dirs/APP_LOCAL_AI_REST/${rest}}"
	fi
	echo "${dirs}"
}
