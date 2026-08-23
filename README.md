# LocalAI Gentoo Overlay

Gentoo packages for [LocalAI](https://localai.io), a self-hosted,
OpenAI-API-compatible AI server. The server core (`sci-ml/local-ai`) and each
inference backend (`app-localai/*`) are separate packages, built from source
against system libraries. See `metadata/docs/specs/` for the design.

## Enabling the overlay

Needs app-eselect/eselect-repository and dev-vcs/git installed. The overlay
declares the GURU repository as a master (some backends depend on packages
from it, e.g. sci-libs/onnxruntime), so enable it first:

    eselect repository enable guru
    emaint sync -r guru
    eselect repository add localai git https://git.ipnmod.org/packages/local-ai-overlay.git
    emaint sync -r localai

This registers the overlay under the name `localai` (checkout managed by
Portage in /var/db/repos/localai, kept up to date by `emerge --sync`).

## Version bumps

1. Copy the ebuilds to the new version.
2. Update the commit pins: `LOCALAI_COMMIT` in `sci-ml/local-ai`,
   `LLAMA_COMMIT` in `app-localai/llama-cpp` (read `LLAMA_VERSION` from
   `backend/cpp/llama-cpp/Makefile` at the new upstream tag).
3. Commit and push, then push a tag `distfiles-v<version>` — the
   release-distfiles Gitea Action generates the dependency tarballs on the
   runner, regenerates and pushes the Manifests, and publishes the release
   under a CI-created `v<version>` tag pointing at the Manifest commit.
4. Build and smoke-test (see metadata/docs/testing.md).
