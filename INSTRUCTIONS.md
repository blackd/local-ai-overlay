# Updating Packages

How to bump any package in this overlay to a new upstream version,
written so that no prior knowledge of the overlay is needed. Terms are
explained the first time they appear.

## How this overlay ships software

This is a Gentoo ebuild repository ("overlay"). Every package builds
from source, offline: all downloads happen before the build, from URLs
listed in the ebuild's `SRC_URI`. Sources come from two places:

- **Upstream archives** (GitHub commit/tag tarballs) — fetched directly
  from the upstream project.
- **Generated dependency tarballs** ("distfiles") — things that normally
  arrive over the network during a build (Go module caches, npm/pnpm
  `node_modules` trees, data snapshots). These are built by the scripts
  in `scripts/gen-<family>-distfiles.sh` and published as **release
  assets** on this repository (git.ipnmod.org), one release per package
  version.

A "family" is a group of packages sharing one release cycle. Current
families: `local-ai` (sci-ml/local-ai + every app-local-ai backend),
`opencode`, `gitea-runner`, `zot`, `dagu`.

### The automated pipeline

Pushing a git tag named `<family>-distfiles-v<version>` (for the
local-ai family, currently plain `distfiles-v<version>`) triggers the
`release-distfiles` workflow (`.gitea/workflows/release-distfiles.yml`),
which:

1. runs `scripts/gen-<family>-distfiles.sh <version>` to build the
   dependency tarballs;
2. regenerates the affected packages' **Manifests** (the checksum files
   Portage uses to verify downloads; this overlay uses full Manifests,
   regenerated with `ebuild <file>.ebuild manifest`) and pushes that
   commit to `master`;
3. publishes the tarballs as a release tagged `<family>-v<version>`.

Two more workflows run nightly: `check-updates` compares every
package's newest ebuild against its upstream's latest release and files
a Gitea issue when the overlay is behind (issues close themselves once
the bump lands on master); `cleanup-releases` deletes releases that no
ebuild references anymore, after 30 days.

### Branches

Development happens on `master`. Consumers sync the `release` branch,
which is only ever fast-forwarded to master manually ("moving the
release") once a change is validated. Nothing is shipped until release
moves.

### The standard bump, step by step

For the standalone packages (opencode, zot, gitea-runner, dagu):

1. Check the upstream diff between the packaged and the new version for
   build-relevant changes: the build script the ebuild calls, dependency
   lockfiles, new patched/vendored components, toolchain version pins.
   Most bumps need nothing beyond the rename; when something changed,
   adjust the ebuild/gen script accordingly.
2. `git mv` the ebuild to the new version (the ebuilds are fully
   `${PV}`-parameterized unless noted below).
3. Commit and push to master.
4. Push a **signed, annotated** tag `<family>-distfiles-v<version>` and
   let the workflow build the tarballs, fix the Manifest and publish the
   release.
5. When the workflow is green, test-build if warranted, then move the
   release branch (which now includes the workflow's Manifest commit —
   `git fetch` before pushing `origin/master:release`).

Per-package notes below list everything that deviates from this.

## Family: local-ai (sci-ml/local-ai + app-local-ai/*)

All packages in this family carry the same version as the LocalAI
release and are bumped together. The backends compile "engine"
libraries (llama.cpp, whisper.cpp, ...) at the exact commits the
LocalAI release pins; each ebuild documents where its pin comes from —
almost always a `<NAME>_VERSION` variable in the corresponding
`backend/go/<name>/Makefile` or `backend/cpp/<name>/` in the LocalAI
source tree at the release tag. Submodule pins (usually ggml) are the
gitlink recorded in the engine repository at that commit (visible via
`git ls-tree <engine-commit> third_party/` or the GitHub API).

At every family bump:

- Re-derive every engine commit and every submodule gitlink; update the
  `*_COMMIT` variables in each backend ebuild.
- Read each engine's build recipe for NEW hidden steps: embedded seds,
  patch stacks, changed CMake option names (see the per-backend notes).
- Planned for the next bump (details in metadata/docs/TODO.md): rename
  the tag scheme to `local-ai-distfiles-v*` / `local-ai-v*` (workflow +
  eclass `DISTFILES_BASE`), drop the 4.9.0-only focus-mode patch in
  sci-ml/local-ai, and switch the node_modules/prebuilt tarballs to the
  prefixed layout (gen script + ebuild `src_unpack` removal together).

### app-local-ai/parakeet-cpp

The engine (mudler/parakeet.cpp) carries a PATCH STACK for its ggml
submodule in `third_party/ggml-patches/`. Upstream applies it during
CMake configure with a script that requires a git checkout and only
WARNS when it cannot run — with unpacked tarballs that means a silently
unpatched ggml. The ebuild therefore replays the stack with `eapply` in
`src_prepare`. The glob picks up whatever patches the new tarball
carries; just expect the patch content to change between engine pins,
and verify the script still targets `third_party/ggml`.

### app-local-ai/whisper

whisper.cpp vendors ggml in-tree (single tarball, no submodule). The
upstream Makefile passes `GGML_HIPBLAS` for ROCm — a toggle this ggml
no longer understands (build silently ends up CPU-only). The eclass
default `GGML_HIP` is correct; do not "fix" the ebuild to match the
Makefile.

### app-local-ai/crispasr

Two submodules (a ggml fork + c2pa-audio). Upstream's clone recipe
hides a sed rewriting `CMAKE_SOURCE_DIR` to `PROJECT_SOURCE_DIR` in the
c2pa-audio sources; the ebuild replicates it in `src_prepare`. At bumps
re-read the recipe for new embedded seds. The `+ffmpeg` USE flag is a
deliberate deviation from upstream's default (they disable it only for
container-size reasons).

### app-local-ai/audio-cpp, llama-cpp, piper, stablediffusion-ggml, vibevoice-cpp, depth-anything

No special steps beyond re-deriving pins. Standing deviations worth
knowing: piper builds against the system onnxruntime (GURU-mirrored,
see below) instead of upstream's bundled copy; llama-cpp applies
`local-ai-backend_bump_cxx20` for the system abseil; depth-anything's
CMake wants `DA_GGML_*` toggle names; vibevoice wants both `GGML_*` and
`VIBEVOICE_GGML_*`. Each ebuild's comments are authoritative.

### app-local-ai/backends-meta

Pure metapackage. When a NEW backend is added: add its default-on USE
flag, its entry in the `REQUIRED_USE` at-least-one list, and its
RDEPEND line. New packages also need locally generated Manifests for
anything without release-asset distfiles (acct-*, metapackages) in the
SAME commit that adds them — the CI Manifest step only covers packages
with generated tarballs.

## Family: opencode (dev-util/opencode)

TypeScript coding agent compiled with Bun into one binary. Upstream
releases very frequently; the nightly issue tracks it. The bump is the
standard flow; in step 1 check `script/build.ts`, the root
`package.json` (`packageManager` pins the Bun version — mirror it in
BDEPEND), and the `patchedDependencies` list (applied by `bun install`
from files inside the source tarball, so lockfile churn is
self-contained). BDEPEND is `dev-lang/bun-bin`, mirrored from GURU (see
below). Pending at next bump: prefixed node_modules tarball layout
(gen script sed + ebuild `src_unpack` deletion together; both drafted
in metadata/docs/TODO.md).

## Family: zot (app-containers/zot)

OCI container registry in Go, with the zui web UI built from source at
the tag zot's Makefile pins (`ZUI_VERSION` — the gen script reads it
automatically). Special cases currently in the ebuild:

- `GOEXPERIMENT=jsonv2` is set only on go older than 1.27 (the
  experiment graduated and the flag disappeared in 1.27).
- `src_prepare` patches trivy's use of the experimental json/v2
  `SkipFunc` API in the module cache (upstream fix:
  aquasecurity/trivy@dc3c56ee). This SELF-RETIRES: once a zot release
  ships a trivy containing that fix, delete the block.
- `CHECKREQS_DISK_BUILD="10G"` — measured; re-measure if the build
  grows.
- Pending at next bump: prefixed zui node_modules tarball (drop
  `src_prepare`'s mv).

## Family: gitea-runner (dev-util/gitea-runner)

Gitea's CI runner daemon, Go. Contains a dormant fallback for hosts
with go older than 1.27 (go.mod relax sed + `GOEXPERIMENT` +
`NONFATAL_VERIFY`) — harmless while go >= 1.27 is installed; delete the
fallback whenever it gets in the way of a bump. Config is generated by
the built binary at install time, not shipped.

## Family: dagu (sys-process/dagu)

Workflow scheduler in Go with an embedded React UI (webpack, pnpm
dependencies — the gen script reads the pnpm version from the UI's
`package.json` `packageManager` field and runs it via npx; the ebuild
builds the UI with plain `npm run build`, no pnpm needed at build
time). Check `Makefile` (build/ui targets) and `ui/package.json` at
bumps. pnpm's blocked-lifecycle-scripts warning during tarball
generation is expected and harmless (verified: esbuild ships prebuilt
binaries as optional dependencies).

## Mirrored GURU packages (no upstream bumps!)

`dev-lang/bun-bin`, `sci-libs/onnxruntime`, `sci-libs/onnxruntime-bin`,
`sci-libs/dlpack`, `dev-cpp/safeint` are verbatim copies from the GURU
overlay, kept so this overlay is self-contained. They follow GURU, NOT
their real upstreams — the nightly check watches GURU's history and
files a `guru-sync:` issue when GURU changes one. To sync:

1. Copy the changed files from a GURU checkout (`diff -r` against
   `gentoo-mirror/guru` or a local clone).
2. Re-apply the standing deviations: remove `~arm64` from KEYWORDS,
   regenerate the full Manifest (GURU uses thin Manifests without
   EBUILD lines; this overlay does not).
3. Update the commit hash in `scripts/guru-sync.state` (the issue body
   contains the exact sed command) — the next nightly run then closes
   the issue.

## After any bump

- The nightly `check-updates` issue for the package closes
  automatically on the next run once master carries the new version.
- Release-branch move ships it to consumers; nothing is public before
  that.
- If a NEW distfile-producing package was added, wire it into all three
  places: the `release-distfiles.yml` family case map, the
  `cleanup-releases.yml` FAMILIES table, and the UPSTREAMS table in
  `scripts/check-updates.sh` (GURU mirrors go in `guru-sync.state`
  instead).
