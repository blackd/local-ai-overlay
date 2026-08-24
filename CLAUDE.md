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

## Layout

- `metadata/docs/specs/` — design documents.
- `sci-ml/local-ai/` — the core LocalAI server package.
- `app-local-ai/*` — one package per inference backend (e.g. `llama-cpp`).
- `scripts/` — maintainer tooling (distfile tarball generation).
