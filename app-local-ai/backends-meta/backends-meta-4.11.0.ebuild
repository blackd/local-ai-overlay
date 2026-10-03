# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Meta package selecting which LocalAI inference backends are installed.
# Backend selection lives here rather than on sci-ml/local-ai so that
# toggling a backend never rebuilds the server: this package installs no
# files, so USE changes only add or remove the backend packages.

EAPI=8

DESCRIPTION="Meta package selecting LocalAI inference backends"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+acestep-cpp +audio-cpp +bonsai +ced +crispasr +depth-anything +diffusers +face-detect +fish-speech +ik-llama-cpp +kimodocpp +llama-cpp +localvqe +locate-anything-cpp +parakeet-cpp +piper +qwen3-tts-cpp +rerankers +rfdetr-cpp +sam3-cpp +silero-vad +stablediffusion-ggml +trellis2cpp +vibevoice-cpp +vllm-cpp +whisper"
# An empty meta package is a configuration error: the whole point is to
# have at least one inference backend installed.
REQUIRED_USE="|| ( acestep-cpp audio-cpp bonsai ced crispasr depth-anything diffusers face-detect fish-speech ik-llama-cpp kimodocpp llama-cpp localvqe locate-anything-cpp parakeet-cpp piper qwen3-tts-cpp rerankers rfdetr-cpp sam3-cpp silero-vad stablediffusion-ggml trellis2cpp vibevoice-cpp vllm-cpp whisper )"

RDEPEND="
	acestep-cpp? ( app-local-ai/acestep-cpp )
	audio-cpp? ( app-local-ai/audio-cpp )
	bonsai? ( app-local-ai/bonsai )
	ced? ( app-local-ai/ced )
	crispasr? ( app-local-ai/crispasr )
	depth-anything? ( app-local-ai/depth-anything )
	diffusers? ( app-local-ai/diffusers )
	face-detect? ( app-local-ai/face-detect )
	fish-speech? ( app-local-ai/fish-speech )
	ik-llama-cpp? ( app-local-ai/ik-llama-cpp )
	kimodocpp? ( app-local-ai/kimodocpp )
	llama-cpp? ( app-local-ai/llama-cpp )
	localvqe? ( app-local-ai/localvqe )
	locate-anything-cpp? ( app-local-ai/locate-anything-cpp )
	parakeet-cpp? ( app-local-ai/parakeet-cpp )
	piper? ( app-local-ai/piper )
	qwen3-tts-cpp? ( app-local-ai/qwen3-tts-cpp )
	rerankers? ( app-local-ai/rerankers )
	rfdetr-cpp? ( app-local-ai/rfdetr-cpp )
	sam3-cpp? ( app-local-ai/sam3-cpp )
	silero-vad? ( app-local-ai/silero-vad )
	stablediffusion-ggml? ( app-local-ai/stablediffusion-ggml )
	trellis2cpp? ( app-local-ai/trellis2cpp )
	vibevoice-cpp? ( app-local-ai/vibevoice-cpp )
	vllm-cpp? ( app-local-ai/vllm-cpp )
	whisper? ( app-local-ai/whisper )
"
