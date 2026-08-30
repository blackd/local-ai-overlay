# LocalAI Gentoo Overlay

Gentoo packages for [LocalAI](https://localai.io), a self-hosted,
OpenAI-API-compatible AI server. The server core (`sci-ml/local-ai`) and each
inference backend (`app-local-ai/*`) are separate packages, built from source
against system libraries. See `metadata/docs/specs/` for the design.

## Enabling the overlay

Needs app-eselect/eselect-repository and dev-vcs/git installed:

    eselect repository add local-ai git https://git.ipnmod.org/packages/local-ai-overlay.git
    emaint sync -r local-ai

This registers the overlay under the name `local-ai` (checkout managed by
Portage in /var/db/repos/local-ai, kept up to date by `emerge --sync`).

A few dependency packages (sci-libs/onnxruntime, sci-libs/onnxruntime-bin,
sci-libs/dlpack, dev-cpp/safeint) are copied verbatim from the GURU
community repository so this overlay works on its own. GURU carries many
more useful packages and usually fresher versions of these copies, so we
strongly suggest enabling it as well:

    eselect repository enable guru
    emaint sync -r guru

## Version bumps

1. Copy the ebuilds to the new version.
2. Update the commit pins: `LOCAL_AI_COMMIT` in `sci-ml/local-ai`,
   `LLAMA_COMMIT` in `app-local-ai/llama-cpp` (read `LLAMA_VERSION` from
   `backend/cpp/llama-cpp/Makefile` at the new upstream tag).
3. Commit and push, then push a tag `distfiles-v<version>` — the
   release-distfiles Gitea Action generates the dependency tarballs on the
   runner, regenerates and pushes the Manifests, and publishes the release
   under a CI-created `v<version>` tag pointing at the Manifest commit.
4. Build and smoke-test (see metadata/docs/testing.md).
