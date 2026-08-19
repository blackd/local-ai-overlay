# LocalAI Gentoo Overlay

Gentoo packages for [LocalAI](https://localai.io), a self-hosted,
OpenAI-API-compatible AI server. The server core (`sci-ml/local-ai`) and each
inference backend (`app-localai/*`) are separate packages, built from source
against system libraries. See `metadata/docs/specs/` for the design.

## Enabling the overlay

Needs app-eselect/eselect-repository and dev-vcs/git installed.

    eselect repository add localai git https://git.ipnmod.org/mirinimi/local-ai-overlay.git
    emaint sync -r localai

This registers the overlay under the name `localai` (checkout managed by
Portage in /var/db/repos/localai, kept up to date by `emerge --sync`).

## Version bumps

1. Copy the ebuilds to the new version.
2. Update the commit pins: `LOCALAI_COMMIT` in `sci-ml/local-ai`,
   `LLAMA_COMMIT` in `app-localai/llama-cpp` (read `LLAMA_VERSION` from
   `backend/cpp/llama-cpp/Makefile` at the new upstream tag).
3. Run `scripts/gen-distfiles.sh <new-version>` on a networked machine.
4. Create a Gitea release on mirinimi/local-ai-overlay tagged `v<version>`
   and attach the three generated tarballs as release assets.
5. Regenerate Manifests: `ebuild <pkg>.ebuild manifest` for each package.
6. Build and smoke-test (see metadata/docs/specs, "Acceptance / smoke test").
