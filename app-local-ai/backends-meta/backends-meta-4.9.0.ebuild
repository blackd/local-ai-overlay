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
IUSE="+llama-cpp +audio-cpp +crispasr +depth-anything +parakeet-cpp +piper +rfdetr-cpp +stablediffusion-ggml +vibevoice-cpp +whisper"
# An empty meta package is a configuration error: the whole point is to
# have at least one inference backend installed.
REQUIRED_USE="|| ( llama-cpp audio-cpp crispasr depth-anything parakeet-cpp piper rfdetr-cpp stablediffusion-ggml vibevoice-cpp whisper )"

RDEPEND="
	llama-cpp? ( app-local-ai/llama-cpp )
	audio-cpp? ( app-local-ai/audio-cpp )
	crispasr? ( app-local-ai/crispasr )
	depth-anything? ( app-local-ai/depth-anything )
	parakeet-cpp? ( app-local-ai/parakeet-cpp )
	piper? ( app-local-ai/piper )
	rfdetr-cpp? ( app-local-ai/rfdetr-cpp )
	stablediffusion-ggml? ( app-local-ai/stablediffusion-ggml )
	vibevoice-cpp? ( app-local-ai/vibevoice-cpp )
	whisper? ( app-local-ai/whisper )
"
