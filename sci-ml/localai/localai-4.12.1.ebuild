# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# The single world entry for a LocalAI host: hard-depends on the server
# and selects which inference backends are installed. Selection lives
# here rather than on the server package so that toggling a backend never
# rebuilds the server: this package installs no files, so USE changes
# only add or remove the backend packages. The backends carry no server
# dependency of their own — removing this package from world lets
# depclean sweep the whole stack.

EAPI=8

DESCRIPTION="Meta package pulling the LocalAI server and selected inference backends"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+acestep-cpp +audio-cpp +bonsai +ced +crispasr +depth-anything +diffusers +face-detect +faster-whisper +fish-speech +ik-llama-cpp +kimodocpp +liquid-audio +llama-cpp +localvqe +locate-anything-cpp +parakeet-cpp +piper +qwen3-tts-cpp +rerankers +rfdetr-cpp +sam3-cpp +silero-vad +speaker-recognition +stablediffusion-ggml +trellis2cpp +transformers +vibevoice +vibevoice-cpp +vllm-cpp +voxcpm +whisper"
# No REQUIRED_USE: with every backend flag off this is a bare server
# install — the package always anchors www-apps/localai-server.

RDEPEND="
	www-apps/localai-server
	acestep-cpp? ( localai-backend/acestep-cpp )
	audio-cpp? ( localai-backend/audio-cpp )
	bonsai? ( localai-backend/bonsai )
	ced? ( localai-backend/ced )
	crispasr? ( localai-backend/crispasr )
	depth-anything? ( localai-backend/depth-anything )
	diffusers? ( localai-backend/diffusers )
	face-detect? ( localai-backend/face-detect )
	faster-whisper? ( localai-backend/faster-whisper )
	fish-speech? ( localai-backend/fish-speech )
	ik-llama-cpp? ( localai-backend/ik-llama-cpp )
	kimodocpp? ( localai-backend/kimodocpp )
	liquid-audio? ( localai-backend/liquid-audio )
	llama-cpp? ( localai-backend/llama-cpp )
	localvqe? ( localai-backend/localvqe )
	locate-anything-cpp? ( localai-backend/locate-anything-cpp )
	parakeet-cpp? ( localai-backend/parakeet-cpp )
	piper? ( localai-backend/piper )
	qwen3-tts-cpp? ( localai-backend/qwen3-tts-cpp )
	rerankers? ( localai-backend/rerankers )
	rfdetr-cpp? ( localai-backend/rfdetr-cpp )
	sam3-cpp? ( localai-backend/sam3-cpp )
	silero-vad? ( localai-backend/silero-vad )
	speaker-recognition? ( localai-backend/speaker-recognition )
	stablediffusion-ggml? ( localai-backend/stablediffusion-ggml )
	trellis2cpp? ( localai-backend/trellis2cpp )
	transformers? ( localai-backend/transformers )
	vibevoice? ( localai-backend/vibevoice )
	vibevoice-cpp? ( localai-backend/vibevoice-cpp )
	vllm-cpp? ( localai-backend/vllm-cpp )
	voxcpm? ( localai-backend/voxcpm )
	whisper? ( localai-backend/whisper )
"
