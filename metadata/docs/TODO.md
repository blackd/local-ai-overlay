# Open tasks

A running list of unfinished work in and around this overlay, so any
session (human or AI-assisted) can pick up where the last one stopped.

## dev-util/opencode

- Write `dev-util/opencode/metadata.xml` (package has none yet; pkgcheck
  flags it).
- First pipeline run: push tag `opencode-distfiles-v1.18.25`, verify the
  workflow publishes the `opencode-v1.18.25` release with both assets and
  pushes the regenerated Manifest.
- Test the install phase and a runtime smoke test on the build machine
  (only `ebuild ... compile` has been verified so far).
- Add a sentence to README.md explaining the overlay also carries
  AI-related tools beyond LocalAI (scope widened by opencode).

## Official listing

- Push the prepared `local-ai-overlay` branch of the api-gentoo-org clone
  (commit "repositories: add LocalAI") to a GitHub fork and open the pull
  request against gentoo/api-gentoo-org.

## LocalAI backends

- Verify depth-anything and crispasr at runtime on the build machine
  (crispasr compiles; audio-cpp runtime check is also still open).
- Continue packaging by gallery-usage ranking: rfdetr-cpp and
  parakeet-cpp (11 models each), vllm-cpp and qwen3-tts-cpp (10), bonsai
  (8), then the tail.

## Runner infrastructure (gitea-gentoo-runner)

- Ryzen variant bootstrap: register the `gentoo-ryzen` runner on the
  ryzen node, set the binhost URL in `variants/ryzen/make.conf.local`,
  point that VM's nightly rsync at `variants/ryzen/overlay/`, create its
  `scripts/variant.sh`, then dispatch the build with `variant=ryzen`,
  `base=...:westmere-latest`, `full=true`.

## Upstream contributions (LocalAI)

- One-line fixes ready to send: voxcpm ROCm torchaudio pin, whisper
  Makefile GGML_HIPBLAS -> GGML_HIP.
- diffusers device auto-detect (patch drafted in conversation) plus the
  missing `cuda: true` in 4 of 6 gallery diffusers entries.
- Issue reports: stable-diffusion.cpp aborts on image requests against
  LTX audio-video models (ltxv.hpp assert); LocalAI could gate requests
  on `known_usecases`.

## Housekeeping

- Advance the `release` branch after the opencode pipeline is validated.
- Delete `~/tmp/portage` (2.9G opencode test build) and `~/tmp/pcfg`
  (defunct config-root experiment) when no longer needed.
