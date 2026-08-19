# LocalAI Gentoo Overlay Implementation Plan

> **Execution note:** This plan is written for human-driven execution (the
> maintainer works through tasks in order), not for automated agent workers.
> Steps use checkbox (`- [ ]`) syntax for tracking. Each step is one small
> action with exact file contents and commands.

**Background:** LocalAI (https://localai.io) is a self-hosted AI server with
an OpenAI-compatible HTTP API. The server (written in Go, with an embedded
React web UI) delegates model inference to separate backend programs that it
talks to over gRPC. This plan builds a Gentoo overlay (a third-party
repository of ebuild build recipes) that compiles LocalAI and its llama.cpp
text-generation backend from source, using system libraries from Portage.
Full design and rationale: `metadata/docs/specs/2026-08-15-gentoo-ebuild-design.md`
(read it first — this plan implements exactly that spec).

**Goal:** A working overlay providing `sci-ml/local-ai` (core server) and
`app-localai/llama-cpp` (backend), buildable offline under Portage's network
sandbox, plus the maintainer script that generates the required dependency
tarballs.

**Architecture:** Separate packages per component; a shared
`localai-backend.eclass` holds cross-package constants and install helpers.
Network-fetched build inputs (Go modules, npm packages, generated protobuf
Go files) are packed into tarballs by `scripts/gen-distfiles.sh` on a
networked machine and hosted on the maintainer's server.

**Tech stack:** ebuilds (EAPI 8), OpenRC + systemd service files, bash,
CMake (backend), Go + npm/vite (core).

**Version targeted:** LocalAI v4.8.2. Tag commit
`5ff25d9d145e0a03a5b9a3559c620f1e1204ca6d`; llama.cpp pin (from
`backend/cpp/llama-cpp/Makefile` at the tag)
`221f0f6356efe2260023208365705ec5d5a7c8f5`.

**Conventions used below:**
- `OVERLAY=~/development/gentoo/local-ai-overlay`
- All `git commit` steps are performed by the human maintainer.
- `DISTFILES_BASE` lives in exactly one file (the eclass) and points at the
  overlay repo's Gitea release assets:
  `https://git.ipnmod.org/mirinimi/local-ai-overlay/releases/download/v${PV}`.

---

## Task 1: Overlay skeleton

**Files:**
- Create: `metadata/layout.conf`
- Create: `profiles/repo_name`
- Create: `profiles/categories`
- Create: `README.md`

- [x] **Step 1: Create `metadata/layout.conf`**

```ini
masters = gentoo
repo-name = localai
thin-manifests = false
sign-manifests = false
```

- [x] **Step 2: Create `profiles/repo_name`**

```
localai
```

- [x] **Step 3: Create `profiles/categories`**

The overlay introduces one category that does not exist in the main Gentoo
tree; Portage only accepts it if it is declared here. (`sci-ml`, where the
core package lives, is an official category and must not be re-declared.)

```
app-localai
```

- [x] **Step 4: Create `README.md`**

```markdown
# LocalAI Gentoo Overlay

Gentoo packages for [LocalAI](https://localai.io), a self-hosted,
OpenAI-API-compatible AI server. The server core (`sci-ml/local-ai`) and each
inference backend (`app-localai/*`) are separate packages, built from source
against system libraries. See `metadata/docs/specs/` for the design.

## Enabling the overlay

Create `/etc/portage/repos.conf/localai.conf`:

    [localai]
    location = /home/plamen/development/gentoo/local-ai-overlay
    masters = gentoo
    auto-sync = no

## Version bumps

1. Copy the ebuilds to the new version.
2. Update the commit pins: `LOCALAI_COMMIT` in `sci-ml/local-ai`,
   `LLAMA_COMMIT` in `app-localai/llama-cpp` (read `LLAMA_VERSION` from
   `backend/cpp/llama-cpp/Makefile` at the new upstream tag).
3. Run `scripts/gen-distfiles.sh <new-version>` on a networked machine.
4. Upload the generated tarballs to the distfiles server (manual step).
5. Regenerate Manifests: `ebuild <pkg>.ebuild manifest` for each package.
6. Build and smoke-test (see metadata/docs/specs, "Acceptance / smoke test").
```

- [x] **Step 5: Sanity-check with Portage tooling**

Run: `cd $OVERLAY && pkgcheck scan 2>&1 | head -20` (if pkgcheck is
installed; otherwise skip — later `ebuild manifest` calls will catch layout
errors).
Expected: no errors about repo layout (empty-tree warnings are fine).

- [ ] **Step 6: Commit**

```bash
git add metadata profiles README.md
git commit -m "overlay skeleton: layout, repo name, custom categories"
```

---

## Task 2: Service user and group packages

LocalAI runs as a dedicated unprivileged user. Gentoo models users/groups as
packages via the `acct-user`/`acct-group` eclasses.

**Files:**
- Create: `acct-group/localai/localai-0.ebuild`
- Create: `acct-group/localai/metadata.xml`
- Create: `acct-user/localai/localai-0.ebuild`
- Create: `acct-user/localai/metadata.xml`

Note: the ebuild file name is always `${PN}-${PV}.ebuild` where `PN` is the
package directory name — here `localai`, giving `localai-0.ebuild` (pkgcheck
reports `MismatchedPN` otherwise).

- [x] **Step 1: Create `acct-group/localai/localai-0.ebuild`**

```bash
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-group

# -1 = allocate the next free GID at install time (fixed IDs are only
# mandatory for packages in the main Gentoo tree).
ACCT_GROUP_ID=-1
```

- [x] **Step 2: Create `acct-user/localai/localai-0.ebuild`**

```bash
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

ACCT_USER_ID=-1
ACCT_USER_GROUPS=( localai )
ACCT_USER_HOME=/var/lib/localai

acct-user_add_deps
```

- [x] **Step 3: Create both `metadata.xml` files** (same content for each;
  the comment must stay on a single line — pkgcheck's indentation check
  rejects mixed tab/space continuation lines):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE pkgmetadata SYSTEM "https://www.gentoo.org/dtd/metadata.dtd">
<pkgmetadata>
	<!-- Maintainer: Plamen K. Kosseff. No email by choice: GLEP 68 makes <email> mandatory inside <maintainer>, hence no maintainer element. -->
</pkgmetadata>
```

- [x] **Step 4: Generate Manifests**

Run: `cd $OVERLAY/acct-group/localai && ebuild localai-0.ebuild manifest`
Run: `cd $OVERLAY/acct-user/localai && ebuild localai-0.ebuild manifest`
Expected: `Manifest` files created without error (they will be empty of
DIST entries — these packages have no source archives).

- [ ] **Step 5: Commit**

```bash
git add acct-group acct-user
git commit -m "acct packages for the localai service user/group"
```

---

## Task 3: The shared eclass

**Files:**
- Create: `eclass/localai-backend.eclass`

- [x] **Step 1: Create `eclass/localai-backend.eclass`**

```bash
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: localai-backend.eclass
# @MAINTAINER:
# Plamen K. Kosseff
# @SUPPORTED_EAPIS: 8
# @BLURB: Shared constants and helpers for LocalAI packages
# @DESCRIPTION:
# LocalAI is a self-hosted AI server whose model inference runs in separate
# backend programs. This eclass is shared by the core server package
# (sci-ml/local-ai) and every backend package (app-localai/*). It defines
# where backends install, where the maintainer-generated dependency tarballs
# are hosted, and the install helper that gives every backend the layout the
# server expects (a directory containing run.sh, discovered by scanning
# LOCALAI_BACKENDS_PATH at runtime).

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_LOCALAI_BACKEND_ECLASS} ]]; then
_LOCALAI_BACKEND_ECLASS=1

# @ECLASS_VARIABLE: DISTFILES_BASE
# @DESCRIPTION:
# Base URL of the maintainer-generated dependency tarballs (Go module cache,
# npm node_modules, pre-generated protobuf Go code). They are produced by
# scripts/gen-distfiles.sh and attached as release assets on the overlay's
# own Gitea repository: one release per LocalAI version, tagged v<version>,
# holding that version's three tarballs.
DISTFILES_BASE="https://git.ipnmod.org/mirinimi/local-ai-overlay/releases/download/v${PV}"

# @ECLASS_VARIABLE: LOCALAI_BACKENDS_DIR
# @DESCRIPTION:
# Install root for backend packages. /usr/libexec is the filesystem-standard
# location for internal executables that must not appear in $PATH; it is not
# split per ABI, so the path is identical on every architecture. Portage
# provides no variable for it, so this eclass is that variable.
LOCALAI_BACKENDS_DIR="${EPREFIX}/usr/libexec/local-ai/backends"

# @ECLASS_VARIABLE: LOCALAI_RUNTIME_BACKENDS_DIR
# @DESCRIPTION:
# The directory the running server actually scans (its LOCALAI_BACKENDS_PATH,
# set by the service files of sci-ml/local-ai). Backend packages symlink
# themselves in here so they appear next to backends the server installs
# itself at runtime.
LOCALAI_RUNTIME_BACKENDS_DIR="/var/lib/localai/backends"

# @FUNCTION: localai-backend_install
# @USAGE: <backend-name> <file>...
# @DESCRIPTION:
# Install <file>s into ${LOCALAI_BACKENDS_DIR}/<backend-name>/, add run.sh
# and metadata.json from FILESDIR, and create the discovery symlink in
# ${LOCALAI_RUNTIME_BACKENDS_DIR}. Executables keep their exec bits via
# doexe; run.sh is always installed executable.
localai-backend_install() {
	local name=$1; shift
	local dest="${LOCALAI_BACKENDS_DIR#${EPREFIX}}/${name}"

	exeinto "${dest}"
	doexe "$@"
	doexe "${FILESDIR}"/run.sh

	insinto "${dest}"
	doins "${FILESDIR}"/metadata.json

	dosym -r "${dest}" "${LOCALAI_RUNTIME_BACKENDS_DIR}/${name}"
}

fi
```

- [x] **Step 2: Syntax-check**

Run: `bash -n $OVERLAY/eclass/localai-backend.eclass`
Expected: no output (exit 0).

- [ ] **Step 3: Commit**

```bash
git add eclass
git commit -m "localai-backend.eclass: shared install dir, distfiles base, install helper"
```

---

## Task 4: Distfile generation script

**Files:**
- Create: `scripts/gen-distfiles.sh`

- [x] **Step 1: Create `scripts/gen-distfiles.sh`**

The script runs on a networked machine, never inside Portage. It creates the
tarballs the ebuilds need; uploading them to the hosting server is a manual
step afterwards.

```bash
#!/usr/bin/env bash
# Generate the dependency tarballs the LocalAI overlay ebuilds need.
#
# Portage builds run with no network access, so anything upstream's build
# would download must be packed ahead of time. This script produces, for a
# given LocalAI release:
#
#   local-ai-<v>-deps.tar.xz          Go module cache (go-module.eclass format)
#   local-ai-<v>-node_modules.tar.xz  npm dependencies of the React web UI
#   local-ai-<v>-prebuilt.tar.xz      the two generated protobuf Go files
#
# The node_modules and prebuilt tarball paths are rooted at the LocalAI
# source tree top level, so ebuilds unpack them directly inside ${S}; the
# deps tarball is rooted at go-mod/ as go-module.eclass expects. Upload the
# results manually.
#
# Usage: gen-distfiles.sh <localai-version>
# Example: gen-distfiles.sh 4.8.2
set -euo pipefail

VERSION=${1:?usage: gen-distfiles.sh <localai-version>}

OUT=$(pwd)/distfiles-out
WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${OUT}"

echo ">>> Fetching LocalAI v${VERSION}"
curl -fL "https://github.com/mudler/LocalAI/archive/refs/tags/v${VERSION}.tar.gz" -o "${WORK}/local-ai.tar.gz"
tar -C "${WORK}" -xf "${WORK}/local-ai.tar.gz"
SRC="${WORK}/LocalAI-${VERSION}"

# The protobuf plugin versions are pinned in upstream's Makefile
# (install-go-tools target). Read them from the downloaded source so the
# generated code always matches the release being packaged, with nothing to
# update here at version bumps.
PROTOC_GEN_GO_VERSION=$(grep -o 'cmd/protoc-gen-go@[^[:space:]]*' "${SRC}/Makefile" | cut -d@ -f2)
PROTOC_GEN_GO_GRPC_VERSION=$(grep -o 'cmd/protoc-gen-go-grpc@[^[:space:]]*' "${SRC}/Makefile" | cut -d@ -f2)
if [[ -z ${PROTOC_GEN_GO_VERSION} || -z ${PROTOC_GEN_GO_GRPC_VERSION} ]]; then
	echo "ERROR: could not read the protoc plugin pins from ${SRC}/Makefile" >&2
	exit 1
fi
echo ">>> plugin pins: protoc-gen-go@${PROTOC_GEN_GO_VERSION}, protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VERSION}"

echo ">>> Go module cache (go-module.eclass -deps format)"
# The go-mod/ directory name is mandated by go-module.eclass: it points
# GOMODCACHE at ${WORKDIR}/go-mod, so a tarball with this root works with
# the eclass's default src_unpack handling.
( cd "${SRC}" && GOMODCACHE="${SRC}/go-mod" go mod download -modcacherw )
XZ_OPT='-T0 -9' tar -C "${SRC}" -acf "${OUT}/local-ai-${VERSION}-deps.tar.xz" go-mod

echo ">>> React UI node_modules"
( cd "${SRC}/core/http/react-ui" && npm ci )
# vite/rollup/esbuild resolve their native binaries via platform-specific
# optional dependency packages chosen at *install* time. Force both Linux
# arches in so one tarball serves amd64 and arm64 builds.
( cd "${SRC}/core/http/react-ui" && npm install --no-save --force @esbuild/linux-x64 @esbuild/linux-arm64 @rollup/rollup-linux-x64-gnu @rollup/rollup-linux-arm64-gnu )
tar -C "${SRC}" -cJf "${OUT}/local-ai-${VERSION}-node_modules.tar.xz" core/http/react-ui/node_modules

echo ">>> Generated protobuf Go code"
GOBIN="${WORK}/gobin" go install "google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VERSION}"
GOBIN="${WORK}/gobin" go install "google.golang.org/grpc/cmd/protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VERSION}"
mkdir -p "${SRC}/pkg/grpc/proto"
( cd "${SRC}" && PATH="${WORK}/gobin:${PATH}" protoc -I backend --go_out=paths=source_relative:pkg/grpc/proto --go-grpc_out=paths=source_relative:pkg/grpc/proto backend/backend.proto )
tar -C "${SRC}" -cJf "${OUT}/local-ai-${VERSION}-prebuilt.tar.xz" pkg/grpc/proto

echo ">>> Done. Upload these to the distfiles server:"
( cd "${OUT}" && sha256sum ./*.tar.xz )
```

- [x] **Step 2: Syntax-check and mark executable**

Run: `bash -n $OVERLAY/scripts/gen-distfiles.sh && chmod +x $OVERLAY/scripts/gen-distfiles.sh`
Expected: exit 0.

- [ ] **Step 3: Trial run (networked machine)**

Run: `cd /tmp && $OVERLAY/scripts/gen-distfiles.sh 4.8.2`
Expected: `distfiles-out/` with the three tarballs and printed SHA256 sums.
Verify the protoc invocation's output file names before proceeding:
`tar -tf distfiles-out/local-ai-4.8.2-prebuilt.tar.xz` must list
`pkg/grpc/proto/backend.pb.go` and `pkg/grpc/proto/backend_grpc.pb.go`.
(If upstream's Makefile uses different protoc flags, copy the exact flags
from its `protogen-go` target instead — the two file names are the contract.)

- [ ] **Step 4: Make the tarballs available to Portage**

Either attach them to a Gitea release tagged `v4.8.2` on
mirinimi/local-ai-overlay, or for local testing copy them into Portage's
distfiles cache:

```bash
cp distfiles-out/local-ai-4.8.2-*.tar.xz /var/cache/distfiles/
```

- [ ] **Step 5: Commit**

```bash
git add scripts/gen-distfiles.sh
git commit -m "gen-distfiles.sh: build offline dependency tarballs per release"
```

---

## Task 5: Core server package (sci-ml/local-ai)

**Files:**
- Create: `sci-ml/local-ai/local-ai-4.8.2.ebuild`
- Create: `sci-ml/local-ai/files/local-ai.confd`
- Create: `sci-ml/local-ai/files/local-ai.initd`
- Create: `sci-ml/local-ai/files/local-ai.service`
- Create: `sci-ml/local-ai/metadata.xml`

- [ ] **Step 1: Create `files/local-ai.confd`** (shared KEY=VALUE environment
  file; sourced by the OpenRC script and read by systemd's EnvironmentFile):

```bash
# Environment for the LocalAI server. Every LOCALAI_* variable the binary
# understands can be set here; see `local-ai run --help`.

# Listen address.
LOCALAI_ADDRESS=:8080

# Where models live and where runtime-installed backends go. The backends
# directory also receives symlinks from Portage-installed backend packages
# (app-localai/*).
LOCALAI_MODELS_PATH=/var/lib/localai/models
LOCALAI_BACKENDS_PATH=/var/lib/localai/backends
```

- [ ] **Step 2: Create `files/local-ai.initd`**

```bash
#!/sbin/openrc-run
# OpenRC service for the LocalAI server.

description="Self-hosted, OpenAI-compatible AI server"
command="/usr/bin/local-ai"
command_args="run"
command_user="localai:localai"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
directory="/var/lib/localai"
output_log="/var/log/local-ai.log"
error_log="/var/log/local-ai.log"

depend() {
	need net
}

start_pre() {
	checkpath -f -o localai:localai "${output_log}"
}
```

(The conf.d file is sourced automatically by OpenRC as `/etc/conf.d/local-ai`;
`export` is not needed because start-stop-daemon passes the init script's
environment to the daemon.)

- [ ] **Step 3: Create `files/local-ai.service`**

```ini
[Unit]
Description=Self-hosted, OpenAI-compatible AI server (LocalAI)
Documentation=https://localai.io
After=network.target

[Service]
User=localai
Group=localai
EnvironmentFile=/etc/conf.d/local-ai
ExecStart=/usr/bin/local-ai run
WorkingDirectory=/var/lib/localai
Restart=on-failure
# The server only needs to write under its state directory.
ProtectSystem=strict
ReadWritePaths=/var/lib/localai
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 4: Create `metadata.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE pkgmetadata SYSTEM "https://www.gentoo.org/dtd/metadata.dtd">
<pkgmetadata>
	<!-- Maintainer: Plamen K. Kosseff (no email by choice; GLEP 68 makes
	     <email> mandatory inside <maintainer>, so no maintainer element) -->
	<upstream>
		<remote-id type="github">mudler/LocalAI</remote-id>
	</upstream>
	<use>
		<flag name="llama-cpp">Install the llama.cpp text-generation backend
		(<pkg>app-localai/llama-cpp</pkg>)</flag>
	</use>
</pkgmetadata>
```

- [ ] **Step 5: Create `local-ai-4.8.2.ebuild`**

```bash
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI is a self-hosted, OpenAI-API-compatible AI server. This package
# builds the core server only: the HTTP API, the web UI and the
# model/backend manager. Model inference happens in backend programs
# packaged separately under the app-localai/ category.

EAPI=8

inherit go-module localai-backend systemd

# Commit hash the upstream v4.8.2 release tag points at. Embedded into the
# binary (internal.Commit) so `local-ai --version` reports the same build
# metadata as upstream's official builds.
LOCALAI_COMMIT="5ff25d9d145e0a03a5b9a3559c620f1e1204ca6d"

DESCRIPTION="Self-hosted, OpenAI-compatible AI server (core, without inference backends)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	https://github.com/mudler/LocalAI/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${DISTFILES_BASE}/${P}-deps.tar.xz
	${DISTFILES_BASE}/${P}-node_modules.tar.xz
	${DISTFILES_BASE}/${P}-prebuilt.tar.xz
"
S="${WORKDIR}/LocalAI-${PV}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Backend flags do not change how the core is built; they only pull in the
# matching backend package so a plain `emerge local-ai` yields a server that
# can actually run models.
IUSE="+llama-cpp"

RDEPEND="
	acct-group/localai
	acct-user/localai
"
PDEPEND="
	llama-cpp? ( app-localai/llama-cpp )
"
# go.mod declares `go 1.26.0`. nodejs[npm] builds the web UI; the UI's
# dependencies come from the node_modules tarball, not the network.
BDEPEND="
	>=dev-lang/go-1.26
	net-libs/nodejs[npm]
"

DOCS=( README.md )

src_unpack() {
	# ${P}-deps.tar.xz unpacks to ${WORKDIR}/go-mod — exactly where
	# go-module.eclass points GOMODCACHE, so Go finds every dependency
	# offline with no further setup.
	unpack "${P}.tar.gz" "${P}-deps.tar.xz"

	# The remaining two tarballs are rooted at the repository top level
	# (core/http/react-ui/node_modules/, pkg/grpc/proto/), so they unpack
	# inside the source tree. This layout is the contract with
	# scripts/gen-distfiles.sh.
	cd "${S}" || die
	unpack "${P}-node_modules.tar.xz"
	unpack "${P}-prebuilt.tar.xz"
}

src_compile() {
	# Step 1: the web UI (React). Runs vite from the unpacked
	# node_modules, fully offline. The output (dist/) is embedded into
	# the Go binary at compile time (go:embed).
	pushd core/http/react-ui >/dev/null || die
	npm run build || die "web UI build failed"
	popd >/dev/null || die

	# Step 2: the server. Upstream's `make build` is bypassed on purpose:
	# it downloads Go tools and regenerates protobuf code, which the
	# network sandbox forbids; those generated files came from the
	# -prebuilt tarball. The Go module cache unpacked by the eclass
	# covers every dependency offline.
	local ldflags=(
		-s -w
		-X "github.com/mudler/LocalAI/internal.Version=v${PV}"
		-X "github.com/mudler/LocalAI/internal.Commit=${LOCALAI_COMMIT}"
	)
	ego build -ldflags "${ldflags[*]}" -o local-ai ./cmd/local-ai
}

src_install() {
	dobin local-ai

	newinitd "${FILESDIR}"/local-ai.initd local-ai
	newconfd "${FILESDIR}"/local-ai.confd local-ai
	systemd_dounit "${FILESDIR}"/local-ai.service

	# All mutable state (models, runtime-installed backends, generated
	# configuration) lives here; the service files above point the server
	# at it. Backend packages symlink themselves into backends/.
	keepdir /var/lib/localai /var/lib/localai/backends /var/lib/localai/models
	fowners -R localai:localai /var/lib/localai

	einstalldocs
}

pkg_postinst() {
	elog "The LocalAI core server is installed. Inference backends are separate"
	elog "packages: app-localai/llama-cpp provides text generation (GGUF models)."
	elog "Mutable state lives in /var/lib/localai."
	elog "Start via: rc-service local-ai start   (OpenRC)"
	elog "       or: systemctl start local-ai    (systemd)"
}
```

- [ ] **Step 6: Generate the Manifest**

Requires the distfiles from Task 4 present (uploaded, or copied into
`/var/cache/distfiles`).
Run: `cd $OVERLAY/sci-ml/local-ai && ebuild local-ai-4.8.2.ebuild manifest`
Expected: Manifest with DIST entries for all four archives.

- [ ] **Step 7: Test build**

Run: `emerge -1v --autounmask-write sci-ml/local-ai` (accept keywords as
needed). Watch for: web UI build completing offline; `ego build` finding the
vendor tree; no sandbox network violations.
Expected: merged successfully; `local-ai --version` prints
`v4.8.2 (5ff25d9d145e0a03a5b9a3559c620f1e1204ca6d)`.
Known verification point: confirm the env variable names in the confd file
(`LOCALAI_ADDRESS`, `LOCALAI_MODELS_PATH`) against `local-ai run --help` —
adjust the confd file if any differ.

- [ ] **Step 8: License audit of statically linked deps**

Go binaries statically link every dependency, and go-module.eclass requires
LICENSE= to cover all of them. Run `lichen ./local-ai` (dev-go/lichen; needs
network, so run it on the networked machine once per version bump) and extend
the ebuild's LICENSE beyond "MIT" with what it reports. Until that run,
LICENSE="MIT" is knowingly incomplete.

- [ ] **Step 9: Commit**

```bash
git add sci-ml
git commit -m "sci-ml/local-ai: core server 4.8.2"
```

---

## Task 6: llama.cpp backend package (app-localai/llama-cpp)

**Files:**
- Create: `app-localai/llama-cpp/llama-cpp-4.8.2.ebuild`
- Create: `app-localai/llama-cpp/files/run.sh`
- Create: `app-localai/llama-cpp/files/metadata.json`
- Create: `app-localai/llama-cpp/metadata.xml`

- [x] **Step 1: Verify upstream facts at the v4.8.2 tag** — done, findings:
  - `prepare.sh` is fully offline (no git clone): it applies `patches/*`
    (one patch at v4.8.2), copies `tools/server/*` plus the wrapper sources
    AND the helper headers into `tools/grpc-server/`, generates
    `llama_compat.h` via a fork-skew probe, and appends
    `add_subdirectory(grpc-server)` itself. Consequence: the ebuild runs
    `prepare.sh` verbatim instead of replicating it.
  - `metadata.json` is optional and all `BackendMetadata` fields are
    `omitempty` — the minimal `{"name": "llama-cpp"}` is valid.
  - GPU handling follows `sci-ml/ggml` (same GGML build system):
    `rocm.eclass` with `AMDGPU_TARGETS` USE_EXPAND + `rocm_use_hipcc`, and
    `cuda.eclass` (`cuda_src_prepare`/`cuda_add_sandbox`/`cuda_sanitize`).

- [x] **Step 2: Create `files/run.sh`**

```bash
#!/bin/sh
# Entry point the LocalAI server invokes to start this backend.
CURDIR=$(dirname "$(readlink -f "$0")")
# A lib/ subdirectory is only present if the package ever ships shared
# libraries; harmless otherwise.
LD_LIBRARY_PATH="${CURDIR}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export LD_LIBRARY_PATH
exec "${CURDIR}/grpc-server" "$@"
```

- [x] **Step 3: Create `files/metadata.json`**

```json
{
	"name": "llama-cpp"
}
```

- [x] **Step 4: Create `metadata.xml`** (single-line maintainer comment, as
  in Task 2)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE pkgmetadata SYSTEM "https://www.gentoo.org/dtd/metadata.dtd">
<pkgmetadata>
	<!-- Maintainer: Plamen K. Kosseff. No email by choice: GLEP 68 makes <email> mandatory inside <maintainer>, hence no maintainer element. -->
	<upstream>
		<remote-id type="github">mudler/LocalAI</remote-id>
	</upstream>
	<use>
		<flag name="native">Let the bundled ggml library auto-detect the build host's CPU features (-march=native) instead of relying on CFLAGS</flag>
		<flag name="openblas">CPU BLAS acceleration via <pkg>sci-libs/openblas</pkg></flag>
		<flag name="rocm">GPU acceleration on AMD via ROCm/HIP</flag>
		<flag name="vulkan">GPU acceleration via Vulkan</flag>
	</use>
</pkgmetadata>
```

- [x] **Step 5: Create `llama-cpp-4.8.2.ebuild`**

```bash
# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI inference backend for text generation with GGUF-format models:
# LocalAI's grpc-server wrapper compiled together with the llama.cpp
# inference library, at the exact llama.cpp commit this LocalAI release pins
# and patches. Installs entirely under /usr/libexec/local-ai/backends/, so it
# co-exists with any system llama-cpp package.

EAPI=8

ROCM_VERSION=7.2

inherit cmake cuda localai-backend rocm

# The llama.cpp commit LocalAI v4.8.2 builds against. Source of truth:
# backend/cpp/llama-cpp/Makefile (LLAMA_VERSION) at the upstream release tag.
LLAMA_COMMIT="221f0f6356efe2260023208365705ec5d5a7c8f5"

DESCRIPTION="LocalAI text-generation backend (llama.cpp gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	https://github.com/mudler/LocalAI/archive/refs/tags/v${PV}.tar.gz -> local-ai-${PV}.tar.gz
	https://github.com/ggerganov/llama.cpp/archive/${LLAMA_COMMIT}.tar.gz -> llama.cpp-${LLAMA_COMMIT}.tar.gz
"

# The llama.cpp tree must sit at backend/cpp/llama-cpp/llama.cpp inside the
# LocalAI tree: upstream's prepare.sh and the backend CMakeLists assume
# exactly that layout. src_unpack moves it into place.
S="${WORKDIR}/LocalAI-${PV}/backend/cpp/llama-cpp/llama.cpp"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="cuda native openblas rocm test vulkan"
REQUIRED_USE="?? ( cuda rocm ) rocm? ( ${ROCM_REQUIRED_USE} )"
RESTRICT="!test? ( test )"

# The server package provides the localai user and the runtime backends
# directory this backend symlinks into. (sci-ml/local-ai's llama-cpp USE
# flag PDEPENDs back on this package; PDEPEND exists precisely to make such
# cycles installable.)
RDEPEND="
	sci-ml/local-ai
	net-misc/curl
	dev-cpp/abseil-cpp:=
	dev-libs/protobuf:=
	net-libs/grpc:=
	openblas? ( sci-libs/openblas )
	vulkan? ( media-libs/vulkan-loader )
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	rocm? (
		>=dev-util/hip-${ROCM_VERSION}
		>=sci-libs/hipBLAS-${ROCM_VERSION}
		>=sci-libs/rocBLAS-${ROCM_VERSION}
	)
"
DEPEND="${RDEPEND}
	vulkan? ( dev-util/vulkan-headers )
"
# protoc and grpc_cpp_plugin generate the C++ gRPC stubs from backend.proto
# at build time.
BDEPEND="
	dev-libs/protobuf
	net-libs/grpc
	vulkan? ( media-libs/shaderc )
"

src_unpack() {
	default
	# Put llama.cpp where upstream's build system expects it (see S).
	mv "${WORKDIR}/llama.cpp-${LLAMA_COMMIT}" "${S}" || die
}

src_prepare() {
	# Upstream's prepare.sh assembles tools/grpc-server inside the
	# llama.cpp tree: applies LocalAI's patches, copies the gRPC wrapper
	# sources and helper headers, generates llama_compat.h (a fork-skew
	# probe) and registers the subdirectory with CMake. It is entirely
	# offline, so run it as-is instead of replicating logic that shifts
	# between releases.
	pushd "${WORKDIR}/LocalAI-${PV}/backend/cpp/llama-cpp" >/dev/null || die
	bash ./prepare.sh || die "prepare.sh failed"
	popd >/dev/null || die

	cmake_src_prepare

	use cuda && cuda_src_prepare
}

src_configure() {
	local mycmakeargs=(
		# Static ggml/llama linked into one self-contained grpc-server
		# binary (upstream's default backend build).
		-DBUILD_SHARED_LIBS=OFF
		-DLLAMA_CURL=ON
		-DLLAMA_BUILD_TESTS=OFF
		-DLLAMA_BUILD_EXAMPLES=OFF
		# Respect the user's CFLAGS instead of -march=native probing,
		# unless they opt in via USE=native.
		-DGGML_NATIVE=$(usex native)
		-DGGML_BLAS=$(usex openblas)
		-DGGML_VULKAN=$(usex vulkan)
		-DGGML_CUDA=$(usex cuda)
		-DGGML_HIP=$(usex rocm)
		# LocalAI's own C++ unit tests for the wrapper sources.
		-DLLAMA_GRPC_BUILD_TESTS=$(usex test)
	)
	use openblas && mycmakeargs+=( -DGGML_BLAS_VENDOR=OpenBLAS )

	if use rocm; then
		# Switch to hipcc and strip flags it can't digest; build for the
		# GPU architectures selected via AMDGPU_TARGETS USE_EXPAND flags
		# (rocm.eclass) instead of autodetecting the build host's GPU.
		rocm_use_hipcc
		mycmakeargs+=(
			-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
			-DCMAKE_HIP_ARCHITECTURES="$(get_amdgpu_flags)"
		)
	fi

	if use cuda; then
		cuda_add_sandbox -w
		addpredict "/dev/char/"
		cuda_sanitize
		mycmakeargs+=( -DCMAKE_CUDA_FLAGS="${NVCCFLAGS}" )
	fi

	cmake_src_configure
}

src_compile() {
	cmake_src_compile grpc-server
}

src_test() {
	cmake_src_test
}

src_install() {
	# LocalAI discovers backends by scanning its backends directory for
	# subdirectories containing run.sh; nothing goes into PATH or the
	# library directories — hence no collision with a system llama-cpp.
	localai-backend_install llama-cpp "${BUILD_DIR}"/tools/grpc-server/grpc-server
}
```

- [ ] **Step 6: Generate the Manifest**

Run: `cd $OVERLAY/app-localai/llama-cpp && DISTDIR=~/development/gentoo/distfiles ebuild llama-cpp-4.8.2.ebuild manifest`
Expected: DIST entries for the LocalAI tarball and the llama.cpp commit
tarball.

- [ ] **Step 7: Test build (system gRPC, CPU)** — on the build machine, not
  this binpkg-only host.

Run: `emerge -1v app-localai/llama-cpp`
Expected: CMake resolves gRPC/Protobuf/absl from the system; the
`grpc-server` target builds; files land in
`/usr/libexec/local-ai/backends/llama-cpp/{grpc-server,run.sh,metadata.json}`
with the symlink `/var/lib/localai/backends/llama-cpp` in place.
If `find_package(gRPC CONFIG)` fails or version skew breaks the build,
record the error and revisit the bundled-gRPC fallback (see the linking
decision in the spec).

- [ ] **Step 8: Verify collision-freedom**

Run: `qlist llama-cpp | grep -v ^/usr/libexec/local-ai | grep -v ^/var/lib/localai`
Expected: no output (every installed file is inside the backend directory or
its symlink).

- [ ] **Step 9: Commit**

```bash
git add app-localai
git commit -m "app-localai/llama-cpp: llama.cpp backend 4.8.2"
```

---

## Task 7: End-to-end smoke test

No new files. Verifies the acceptance criteria from the spec.

- [ ] **Step 1: Start the service**

OpenRC: `rc-service local-ai start` — or systemd: `systemctl start local-ai`.
Expected: `curl -s localhost:8080/readyz` (or `/v1/models`) answers.

- [ ] **Step 2: Backend discovery**

Run: `local-ai backends list --backends-path /var/lib/localai/backends`
(or check the web UI's backends page at `http://localhost:8080`).
Expected: `llama-cpp` listed as installed (system backend).

- [ ] **Step 3: Inference round-trip**

Install a small GGUF model through the web UI gallery (or
`local-ai models install <small-model>`), then:

```bash
curl -s http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"<installed-model>","messages":[{"role":"user","content":"Say hi"}]}'
```

Expected: a JSON chat completion produced by the Portage-built backend.

- [ ] **Step 4: Coexistence check** (only if Portage's llama-cpp is wanted):

Run: `emerge -1v llama-cpp && qcheck app-localai/llama-cpp`
Expected: both packages installed, no collisions, `llama-server` (system)
and the LocalAI backend both functional.

- [ ] **Step 5: Commit any fixes discovered, then tag the overlay state**

```bash
git add -A && git commit -m "fixes from first end-to-end run"
```

---

## Known verification points (collected)

These are facts asserted from reading the source that MUST be confirmed
against a real v4.8.2 build during execution; each is embedded in the task
where it bites:

1. `prepare.sh` copy list and how `tools/grpc-server` joins the CMake build
   (Task 6, Step 1).
2. `metadata.json` minimal schema (Task 6, Step 1).
3. protoc flags / output layout for the Go stubs (Task 4, Step 3).
4. confd env variable names vs `local-ai run --help` (Task 5, Step 7).
5. Which protoc CMake resolves with the bundled gRPC prefix (Task 6, Step 7).
6. ROCm compiler/`AMDGPU_TARGETS` handling — copy the idiom from Portage's
   own llama-cpp ebuild when first testing USE=rocm; the plan's `GGML_HIP`
   switch alone may not be sufficient.
7. The exact ctest wiring for `LLAMA_GRPC_BUILD_TESTS` under `src_test`.
```
