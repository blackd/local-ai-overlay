# LocalAI Gentoo Overlay — Agent Instructions

This repository is a Gentoo overlay (a third-party package repository for the
Gentoo Linux distribution) that packages [LocalAI](https://localai.io) — a
self-hosted, OpenAI-API-compatible AI server — so it builds from source using
libraries from Gentoo's package tree (Portage) wherever possible.

## Rules

- **Documentation accessibility**: All documents in this repository (specs,
  plans, READMEs, comments in ebuilds) must be written so someone with no
  prior knowledge of LocalAI or Gentoo packaging can read and understand them.
  Introduce the project and define domain terms (ebuild, overlay, USE flag,
  inference backend, ...) before using them. No unexplained jargon and no
  references to context outside the document itself.
- **No commits without permission**: never run `git commit` unless the user
  explicitly asks for or approves it.
- **Ask before editing files**: do not create or modify files in this
  repository without the user's go-ahead. Show proposed content or changes
  inline first and wait for approval.
- **AI-assisted commits** (the same policy the LocalAI project uses): a
  commit that an AI coding assistant helped produce must end its commit
  message with two trailer lines:
  - `Assisted-by: AGENT_NAME:MODEL_VERSION` — names the AI tool that helped,
    e.g. `Assisted-by: Claude:claude-fable-5`. An AI must never add a
    `Signed-off-by` line of its own or a `Co-Authored-By` line naming an AI.
  - `Signed-off-by: NAME <EMAIL>` — the human contributor's sign-off, using
    the repository's configured git identity. Only the human may add it; it
    records that they reviewed the change and take responsibility for it.
- **No unrelated tool use**: every command or tool invocation an AI
  assistant runs must serve only the user's current request. Do not
  piggyback unrelated actions (git staging, cleanups, preparation for
  anticipated future steps) onto a command run for another purpose —
  propose them separately and wait for approval. When the user asks to see
  a tool's output, show the complete, unfiltered output.

## Layout

- `metadata/docs/specs/` — design documents.
- `sci-ml/local-ai/` — the core LocalAI server package.
- `app-local-ai/*` — one package per inference backend (e.g. `llama-cpp`).
- `scripts/` — maintainer tooling (distfile tarball generation).
