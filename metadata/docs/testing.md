# Build-Machine Test Checklist

This overlay (a third-party Gentoo package repository) provides
`sci-ml/local-ai` — LocalAI, a self-hosted AI server with an
OpenAI-compatible API — and `app-localai/llama-cpp`, its text-generation
backend (a gRPC server embedding the llama.cpp inference library). The
packages were authored and manifested on a machine that cannot compile them
(binary-package-only host), so the checks below must run once on a normal
source-building Gentoo machine. They verify the assumptions that could only
be asserted by reading code, not by building it.

## Prerequisites

- Overlay enabled (see README) and the `v4.8.2` release published on
  git.ipnmod.org/mirinimi/local-ai-overlay with its three tarball assets
  (`local-ai-4.8.2-deps.tar.xz`, `-node_modules.tar.xz`, `-prebuilt.tar.xz`).

## 1. Core server (sci-ml/local-ai)

1. `emerge -1v sci-ml/local-ai`
   - Must succeed with Portage's network sandbox active (no network during
     build). Watch: the web UI builds offline from the unpacked
     node_modules (esbuild/rollup native binaries were force-installed for
     amd64+arm64 at tarball-generation time — an offline vite failure here
     means that trick did not survive an npm upgrade); the Go build finds
     every module in the unpacked module cache.
2. `local-ai --version` → must print `v4.8.2 (5ff25d9d145e0a03a5b9a3559c620f1e1204ca6d)`.
3. Env names: check `local-ai run --help` lists `LOCALAI_ADDRESS`,
   `LOCALAI_MODELS_PATH`, `LOCALAI_BACKENDS_PATH` as used in
   `/etc/conf.d/local-ai`; fix the confd file if any differ.
4. License audit: run `lichen ./local-ai` (dev-go/lichen, needs network) and
   extend the ebuild's `LICENSE="MIT"` with the licenses of statically
   linked Go dependencies it reports.

## 2. Backend (app-localai/llama-cpp)

1. `emerge -1v app-localai/llama-cpp`
   - This is the verdict on the "system gRPC only" decision: CMake must
     resolve gRPC/Protobuf/absl from Portage and build the `grpc-server`
     target. If `find_package(gRPC CONFIG)` fails or version skew breaks
     the build, record the error — the agreed fallback is a private static
     gRPC built from the plain GitHub archive with
     `gRPC_*_PROVIDER=package` (see the linking decision in the design
     spec).
   - Confirm in the build log that the system `protoc`/`grpc_cpp_plugin`
     generated the C++ stubs.
2. Files land in `/usr/libexec/local-ai/backends/llama-cpp/`
   (`grpc-server`, `run.sh`, `metadata.json`) plus the symlink
   `/var/lib/localai/backends/llama-cpp`.
3. Collision-freedom: `qlist llama-cpp | grep -v ^/usr/libexec/local-ai |
   grep -v ^/var/lib/localai` → no output. With Portage's `llama-cpp` also
   installed, `qcheck` both packages.
4. GPU variants when hardware allows: `USE=vulkan`, `USE=cuda`,
   `USE="rocm amdgpu_targets_gfx<yours>"` (ROCm switches the compiler to
   hipcc via rocm.eclass — first real test of that wiring), `USE=openblas`.
5. `FEATURES=test emerge ...` exercises `-DLLAMA_GRPC_BUILD_TESTS=ON` via
   ctest — the exact test-target wiring is unverified; adjust `src_test`
   if targets differ.

## 3. End-to-end smoke test

1. Start the service: `rc-service local-ai start` (OpenRC) or
   `systemctl start local-ai` (systemd); `curl -s localhost:8080/v1/models`
   answers.
2. `local-ai backends list --backends-path /var/lib/localai/backends` (or
   the web UI's backends page) shows `llama-cpp` as installed.
3. Install a small GGUF model via the web UI gallery, then:

       curl -s http://localhost:8080/v1/chat/completions \
         -H 'Content-Type: application/json' \
         -d '{"model":"<model>","messages":[{"role":"user","content":"Say hi"}]}'

   → a JSON chat completion produced by the Portage-built backend.
