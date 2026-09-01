# LocalAI Gentoo Overlay

This overlay packages tools for self-hosted AI, built from source against
system libraries wherever possible:

- [LocalAI](https://localai.io), a self-hosted, OpenAI-API-compatible AI
  server — the centerpiece: the server core (`sci-ml/local-ai`) and each
  inference backend (`app-local-ai/*`) are separate packages
- `dev-util/opencode` — an AI coding agent
- `app-containers/zot` — an OCI-native container image registry
- `dev-util/gitea-runner` — the Gitea Actions CI runner
- dependency copies from the GURU repository (`sci-libs/onnxruntime` and
  friends)

See `metadata/docs/specs/` for the design.

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

## Why a dedicated backend category

The packages under `app-local-ai/` may look like duplicates of software
Gentoo already ships (for example llama.cpp), but they are not
interchangeable with the regular packages:

- A backend is not the upstream tool. It is LocalAI's gRPC server (the
  protocol the LocalAI core uses to talk to its inference processes)
  compiled together with the inference engine's libraries; the engine's
  own programs are not built or installed at all.
- Each LocalAI release pins the exact engine commit it was developed and
  tested against, and sometimes patches it. A system package follows its
  own release schedule, so building the wrapper against one would combine
  code versions that upstream never tested together — inference engines
  change their internal interfaces too quickly for that to work.
- Backends install only under `/usr/libexec/local-ai/backends/<name>/`,
  where the LocalAI server discovers them. Nothing is placed in PATH or
  the system library directories, so a backend can be installed next to
  the regular package (e.g. app-misc/llama-cpp) without file collisions.

System libraries with stable interfaces (gRPC, protobuf, abseil, fmt,
spdlog, onnxruntime, ffmpeg, the ROCm and CUDA stacks, ...) do come from
Portage wherever the engines support it; only the fast-moving inference
engines themselves are built at their pinned commits.

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
