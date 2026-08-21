# LocalAI Gentoo Overlay — Design

Date: 2026-08-15
Status: approved by user (conversation), pending written review

## Background and terminology

**LocalAI** (https://localai.io) is a self-hosted AI server written in Go. It
exposes an OpenAI-compatible HTTP API (chat completions, audio, images, ...)
and a web UI, and runs AI models on the user's own hardware. The server itself
does no inference: actual model execution happens in **backends** — separate
programs the server starts and talks to over gRPC (a remote-procedure-call
protocol). The main text-generation backend embeds **llama.cpp**, a C++
library for running LLMs in the GGUF format. Upstream normally distributes
backends as prebuilt container (OCI) images that the server downloads at
runtime.

**Gentoo** is a Linux distribution that compiles software from source.
Its package manager is **Portage**; a package's build recipe is an **ebuild**
(a bash-based script with well-defined phases: unpack, prepare, configure,
compile, install). A collection of ebuilds outside Gentoo's official tree is
an **overlay**. Other terms used below:

- **USE flag** — a per-package on/off switch a user sets to enable optional
  features (e.g. GPU support); it changes dependencies and build options.
- **SRC_URI** — the list of source archives ("distfiles") an ebuild downloads
  before building. Portage verifies them against checksums recorded in a
  **Manifest** file.
- **Network sandbox** — Portage forbids network access during the build
  phases; everything a build needs must be listed in SRC_URI up front. This is
  why dependency trees that normally download at build time (Go modules, npm
  packages) must be packed into tarballs ahead of time.
- **eclass** — a shared bash library ebuilds can inherit common logic from.
- **DEPEND / BDEPEND / PDEPEND** — dependency classes: libraries linked at
  build time / tools run at build time / packages that can be installed after
  this one, respectively.

## Goal

Package LocalAI for Gentoo, built from source, using libraries from Portage
wherever possible. Backends are vendored builds packaged separately from the
core server so each can pin its own upstream sources and be rebuilt
independently.

## Decisions (agreed)

- **Structure**: separate ebuild per backend, not USE flags on a monolith.
  Core: `sci-ml/local-ai`. Backends: `app-localai/<name>` (e.g.
  `app-localai/llama-cpp`).
- **First iteration**: core + the llama-cpp backend. Other cpp/go backends
  follow the same template later. Python backends stay out of scope (pip
  dependency trees cannot come from Portage); they remain available via
  LocalAI's runtime OCI gallery.
- **Versioning**: pinned release ebuilds (start: v4.8.2). No live -9999 ebuild.
- **Linking**: use system libraries from Portage — gRPC, protobuf, abseil,
  BLAS, Vulkan, CUDA, ROCm; only llama.cpp itself is vendored (bundled at a
  fixed version rather than taken from the system), because LocalAI pins an
  exact llama.cpp commit and applies its own patches, so Portage's `llama-cpp`
  package cannot substitute. Decision 2026-08-16: system gRPC only, no
  bundled fallback — first see whether it builds and works. If the build
  machine proves it incompatible, revisit; the candidate fallback is a
  private static gRPC built from the plain GitHub archive the Gentoo way
  (`gRPC_*_PROVIDER=package` against system abseil/protobuf/re2/openssl —
  see net-libs/grpc), which needs no self-hosted tarball.
- **Web UI**: LocalAI's browser interface (a React application, embedded into
  the server binary at build time) is built from source during the package
  build, offline, from a pre-packed `node_modules` (npm dependency) tarball —
  rather than shipping a pre-built copy of it.
- **Distfiles**: overlay is a git repo (remote:
  `git.ipnmod.org/packages/local-ai-overlay` on the maintainer's Gitea); it
  ships a script that generates the dependency tarballs, which are hosted as
  Gitea release assets on that same repository — one release per LocalAI
  version, tagged `v<version>`. GitHub-fetchable sources (LocalAI release
  tarball, llama.cpp commit tarball) are referenced directly in `SRC_URI`.
- **Coexistence**: `app-localai/llama-cpp` must be co-installable with
  Portage's `llama-cpp`. Achieved by construction: backends install under
  `${EPREFIX}/usr/libexec/local-ai/backends/<name>/` (`/usr/libexec` is the
  filesystem-standard home for internal executables not meant for the user's
  `$PATH`; `${EPREFIX}` is the offset used by Gentoo Prefix installs) and
  never touch `/usr/bin` or the library directories.

## Overlay layout

```
local-ai-overlay/                     (git repo)
├── metadata/layout.conf              masters = gentoo, thin-manifests = false
├── profiles/
│   ├── repo_name                     "localai"
│   └── categories                    app-localai (sci-ml is official, not re-declared)
├── acct-user/localai/                service user (dynamic UID: ACCT_USER_ID=-1, per overlay policy)
├── acct-group/localai/
├── eclass/
│   └── localai-backend.eclass        shared backend logic (see "Eclass" below)
├── sci-ml/local-ai/
│   ├── local-ai-4.8.2.ebuild
│   ├── files/                        OpenRC init.d + conf.d, systemd unit + env file
│   ├── metadata.xml
│   └── Manifest
├── app-localai/llama-cpp/
│   ├── llama-cpp-4.8.2.ebuild        version tracks the LocalAI release it ships with
│   ├── files/                        run.sh, metadata.json template
│   ├── metadata.xml
│   └── Manifest
├── scripts/gen-distfiles.sh
└── metadata/docs/specs/                       this document
```

## Distfile pipeline

`scripts/gen-distfiles.sh <version>` runs once per version bump on a networked
machine. It clones/downloads the LocalAI release, then produces:

1. `local-ai-<v>-deps.tar.xz` — Go module cache in the `-deps` format
   documented by `go-module.eclass` (`GOMODCACHE=go-mod go mod download
   -modcacherw`, tarred). This is Gentoo's official convention for Go
   dependency tarballs; the eclass consumes it with no custom unpack code.
2. `local-ai-<v>-node_modules.tar.xz` — `npm ci` result for
   `core/http/react-ui/` (dependency tree only, no build output).
3. `local-ai-<v>-prebuilt.tar.xz` — generated sources that upstream's build
   creates with network access. Verified against the v4.8.2 Makefile: this is
   exactly two files, `pkg/grpc/proto/backend.pb.go` and
   `pkg/grpc/proto/backend_grpc.pb.go`, generated with the plugin versions
   pinned in the upstream Makefile (`protoc-gen-go` v1.34.2,
   `protoc-gen-go-grpc` pinned commit). Everything else upstream's `generate`
   step needs (`core/config/inference_defaults.json`, `parser_defaults.json`)
   is already committed in the release tarball.

   These two files are Go code for the core server only and are independent
   of any C++ gRPC library. The backend packages do NOT use pre-generated
   stubs: each backend generates its C++ protobuf/gRPC code at build time
   from `backend.proto`, using the system `protoc`/`grpc_cpp_plugin`
   matching the linked system gRPC, so generated code and linked library
   always match. Between server and backend only wire-format
   protobuf messages travel, which is implementation-independent.

The script only creates the tarballs (into a local output directory)
and prints their SHA256 sums; uploading them to the hosting server is done
manually by the maintainer (a Gitea release tagged `v<version>` with the
three tarballs attached). `SRC_URI` references them at
`${DISTFILES_BASE}/...`, defined once in the eclass as the Gitea release
download URL for the package's version.

Precedent note: shipping generated protobuf/go-generate output in a distfile
mirrors autotools packages shipping generated `configure`. The generators are
pinned upstream, so output is deterministic per release.

## sci-ml/local-ai (core server)

- **Eclasses**: `go-module`, `systemd`, `optfeature`.
- **SRC_URI**: GitHub release tarball + the three generated tarballs above.
- **BDEPEND**: `dev-lang/go` (version per upstream `go.mod`),
  `net-libs/nodejs[npm]`. No protoc at build time (protos are prebuilt).
- **src_compile**:
  1. React UI: unpack `node_modules` into `core/http/react-ui/`, run
     `npm run build` (vite) offline; output is embedded into the Go binary via
     `go:embed`.
  2. `go build -ldflags "-X github.com/mudler/LocalAI/internal.Version=v<v>
     -X github.com/mudler/LocalAI/internal.Commit=<tag sha>" ./cmd/local-ai`.
     The tag sha is an ebuild variable recorded at bump time.
  - Upstream's Makefile is bypassed: its `build` target depends on
    `install-go-tools` and `protogen-go`, which need network. The ebuild
    replicates only the offline steps.
  - The desktop launcher (`cmd/launcher`, Fyne/OpenGL) is out of scope.
- **src_test** (`FEATURES=test`): optional; runs the fast Go unit tests that
  need no downloaded fixtures. May be `RESTRICT`ed initially if flaky in
  sandbox.
- **Install**:
  - `/usr/bin/local-ai`.
  - `localai` user/group via `acct-user`/`acct-group` packages; home
    `/var/lib/localai` (`keepdir`), which holds models, generated configs and
    runtime-installed (OCI gallery) backends.
  - OpenRC: `files/local-ai.initd` + `files/local-ai.confd`. systemd:
    `files/local-ai.service` + environment file. Both set
    `LOCALAI_BACKENDS_PATH=/var/lib/localai/backends` and run as
    `localai:localai`.
- **USE flags**: one convenience flag per packaged backend, `PDEPEND`ing on the
  matching `app-localai/` package. Initially: `+llama-cpp`.

## app-localai/llama-cpp (backend)

- **Sources**:
  - LocalAI release tarball (provides `backend/cpp/llama-cpp/`:
    `grpc-server.cpp`, helper headers, `CMakeLists.txt`, `patches/`,
    `prepare.sh` logic).
  - llama.cpp pinned-commit tarball from GitHub
    (`https://github.com/ggerganov/llama.cpp/archive/<commit>.tar.gz`, the
    `LLAMA_REPO` from the upstream Makefile). The
    commit is `LLAMA_VERSION` from `backend/cpp/llama-cpp/Makefile`, recorded
    as an ebuild variable with a comment pointing at that file (bump
    checklist item).
- **src_prepare** (replicates `prepare.sh` without git):
  1. Apply LocalAI's `patches/*` to the llama.cpp tree (`-p1`).
  2. Create `tools/grpc-server/` populated with `tools/server/*` plus
     LocalAI's `grpc-server.cpp`, helper headers and `CMakeLists.txt`.
  3. `eapply_user` (the standard hook letting the system administrator apply
     their own local patches).
- **src_configure**: CMake on the llama.cpp root, target `grpc-server` only.
  `find_package` resolves against Portage: `net-libs/grpc`,
  `dev-libs/protobuf`, `dev-cpp/abseil-cpp`, `net-misc/curl`. `grpc_cpp_plugin`
  and `protoc` come from the same packages (BDEPEND).
  - User CFLAGS respected; `GGML_NATIVE=OFF` by default, `native` USE flag
    turns ggml's own `-march=native` detection on.
  - Static ggml/llama (upstream default `BUILD_SHARED_LIBS=OFF`) → single
    self-contained `grpc-server` binary. If a shared build is ever needed,
    libs stay inside the backend dir with RPATH `$ORIGIN/lib`.
- **Acceleration USE flags**:

  | USE | CMake | Portage deps |
  |-----|-------|--------------|
  | `openblas` | `-DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS` | `sci-libs/openblas` |
  | `vulkan` | `-DGGML_VULKAN=ON` | `media-libs/vulkan-loader`, build: `dev-util/glslang`/`media-libs/shaderc` |
  | `cuda` | `-DGGML_CUDA=ON` | `dev-util/nvidia-cuda-toolkit` |
  | `rocm` | `-DGGML_HIP=ON`, hipcc as compiler | `dev-util/hip`, `sci-libs/hipBLAS`, `sci-libs/rocBLAS` |
  | `native` | `-DGGML_NATIVE=ON` | — |

  `REQUIRED_USE: ?? ( cuda rocm )` — at most one; `vulkan` may coexist.
- **gRPC linking**: always against Portage's gRPC stack (`net-libs/grpc`,
  `dev-libs/protobuf`, `dev-cpp/abseil-cpp`). No bundled fallback for now —
  see the linking decision above for the revisit plan if this proves
  incompatible.
- **Install** (collision-free with Portage's `llama-cpp` by construction —
  LocalAI discovers backends by scanning `LOCALAI_BACKENDS_PATH` for
  subdirectories containing `run.sh`, not via `$PATH`):
  - `${LOCALAI_BACKENDS_DIR}/llama-cpp/` (see the eclass section; expands to
    `${EPREFIX}/usr/libexec/local-ai/backends/llama-cpp/`): `grpc-server`,
    `run.sh`
    (`exec` of the binary, `LD_LIBRARY_PATH` prelude only if shared libs
    exist), minimal `metadata.json` (name, capabilities).
  - Symlink `/var/lib/localai/backends/llama-cpp` → the install dir, so the
    service (BACKENDS_PATH=/var/lib/localai/backends) sees Portage-installed
    and runtime-downloaded backends side by side. Portage-owned backends are
    root-owned; the gallery UI cannot modify them (correct: Portage owns them).
- **src_test** (`FEATURES=test`): configure with
  `-DLLAMA_GRPC_BUILD_TESTS=ON`, run LocalAI's C++ unit tests via ctest.

## Eclass

A `localai-backend.eclass` (overlay `eclass/` dir) is created from the start —
even though the first version is small, starting with it is easier than
extracting shared logic from several ebuilds later. Initial contents:

- `LOCALAI_BACKENDS_DIR="${EPREFIX}/usr/libexec/local-ai/backends"` — the
  single definition of the backend install location (`/usr/libexec` is the
  filesystem-standard home for internal executables; there is no
  Portage-provided variable for it, so the eclass is that variable).
- `DISTFILES_BASE` — base URL of the maintainer-hosted distfiles.
- The default `SRC_URI` entry for the LocalAI release tarball and the
  matching unpack conventions.
- A `localai-backend_src_install` helper: installs the backend binary,
  `run.sh` and `metadata.json` into `${LOCALAI_BACKENDS_DIR}/<name>/` and
  creates the discovery symlink in `/var/lib/localai/backends/`.

As more backends are packaged, whatever they share migrates into the eclass
rather than being copied between ebuilds.

## Version bumps

Checklist (goes in overlay README):

1. Copy ebuilds to the new version.
2. Update `COMMIT` (tag sha) in `sci-ml/local-ai` and `LLAMA_COMMIT` in
   `app-localai/llama-cpp` (from `backend/cpp/llama-cpp/Makefile` of the new
   tag).
3. Run `scripts/gen-distfiles.sh <new-version>`; upload the resulting
   tarballs to the hosting server yourself.
4. `ebuild ... manifest` for both packages.
5. Build-test both, smoke-test (below).

## Acceptance / smoke test

1. `emerge sci-ml/local-ai app-localai/llama-cpp` completes with
   `FEATURES="network-sandbox"`.
2. `local-ai backends list` shows `llama-cpp` as an installed system backend.
3. Start the service (OpenRC or systemd), download a small GGUF model via the
   gallery, run a chat completion through `/v1/chat/completions`.
4. `qcheck`/`qlist` (Portage's installed-file inspection tools) confirm no
   file collisions with an installed Portage `llama-cpp`.

## Open items (need user input at implementation time)

- `DISTFILES_BASE` URL for the user's server.
- Overlay location confirmed as `~/development/gentoo/local-ai-overlay`
  (registered via `/etc/portage/repos.conf` with `location` pointing there).

## Out of scope (this iteration)

- Other backends (whisper, piper, silero-vad, stablediffusion-ggml, …) —
  follow-ups using the `app-localai/llama-cpp` template.
- Python backends (pip trees can't come from Portage).
- The desktop launcher.
- A -9999 live ebuild.
- Upstreaming to GURU / ::gentoo.
