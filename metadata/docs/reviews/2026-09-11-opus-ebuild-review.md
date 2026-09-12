# Code review: local-ai-overlay
*Opus 5 agent review, 2026-09-11. Scope: all original ebuilds/eclasses/scripts/workflows (GURU mirrors excluded).*

**Summary:** The overlay is in good shape — eclass factoring is already well past average for a personal overlay, the "grep || die after sed" convention is followed almost everywhere, and the comments consistently explain *why*. I found 5 genuine correctness bugs (one silent-misbuild, one silent-wrong-layout, one missing-rebuild dependency), and a clear set of remaining eclass-extraction candidates — the biggest being the 12 near-duplicate `files/run.sh` files, which the python eclass already shows how to eliminate.

**Two things I checked and am *not* reporting**, because they looked wrong but are not:
- `IUSE="test"` in llama-cpp/bonsai and `BDEPEND=">=dev-lang/go-1.26.0"` in `local-ai-ggml-go.eclass` do **not** clobber the eclass values. Portage's `inherit` (`ebuild.sh:325-353`) accumulates eclass-set `IUSE`/`*DEPEND` into `E_*` and restores the pre-inherit value, so ebuild-level `VAR=` and `VAR+=` are equivalent. Confirmed against the generated `BDEPEND` for whisper, which carries cmake, ninja, unzip, shaderc *and* go.
- `metadata/md5-cache/` is stale (its `local-ai-ggml` hash no longer matches, `local-ai-rocm` is absent) but it is **untracked** and correctly `.gitignore`d — a local artifact, not repo content.

---

## BUG

**1. `eclass/local-ai-ggml.eclass:82-86` — missing `:=` on the ROCm runtime libraries**
```
rocm? (
    >=dev-util/hip-${ROCM_VERSION}
    >=sci-libs/hipBLAS-${ROCM_VERSION}
    >=sci-libs/rocBLAS-${ROCM_VERSION}
)
```
All three are `SLOT="0/$(ver_cut 1-2)"` in ::gentoo — they carry a subslot precisely so consumers get rebuilt when the ABI moves. Without `:=`, a ROCm 7.2 → 7.3 upgrade leaves every ggml backend linked against a removed soname with no rebuild scheduled. ::gentoo's `sci-ml/pytorch-2.14.0-r2:113-116` and `sci-ml/gloo:39` all use `:=`, and **this overlay's own `local-ai-torch.eclass:69` already does** (`rocm? ( dev-util/hip:= )`) — so it is also an internal inconsistency. Fix: append `:=` to all three atoms.

**2. `eclass/local-ai-backend.eclass:86-91` — suppressed `rmdir` turns a layout surprise into a silently nested tree**
```
while [[ $# -gt 0 ]]; do
    unpack "$1"
    rmdir "${engine_root}/$3" 2>/dev/null
    mv "$2" "${engine_root}/$3" || die
    shift 3
done
```
The `rmdir` is deliberately soft (the placeholder may be absent), but that also swallows the *non-empty* case. If an engine archive ever ships content at the submodule path, `rmdir` fails silently and `mv` then moves the extracted tree **inside** the surviving directory — `sources/parakeet.cpp/third_party/ggml/ggml-<sha>/` instead of `.../ggml/` — and `|| die` never fires. Every caller then builds against an empty submodule dir. Fix: only remove when it is an empty placeholder, and die otherwise:
```
if [[ -e ${engine_root}/$3 ]]; then
    rmdir "${engine_root}/$3" || die "placeholder ${3} is not empty; archive layout changed"
fi
```

**3. `app-local-ai/audio-cpp/audio-cpp-4.9.0-r1.ebuild:64-66` — the C++20 bump silently no-ops if the anchor moves**
```
local files=()
readarray -t files < <(grep -rl 'CMAKE_CXX_STANDARD 17' .)
local-ai-backend_bump_cxx20 "${files[@]}"
```
When `grep -rl` matches nothing it exits 1 and prints nothing; `files` is empty, and `bump_cxx20`'s `for f in "$@"` iterates zero times — no error. The ebuild then configures an upstream-default C++17 build against the system abseil that *requires* C++20, which is exactly the failure the helper exists to prevent. Every other sed site in this overlay has a `grep || die` anchor check; this one is the exception. Fix:
```
[[ ${#files[@]} -gt 0 ]] || die "no CMAKE_CXX_STANDARD 17 anchors found"
```

**4. `scripts/gen-local-ai-distfiles.sh:49-50` — missing the Go-toolchain strip every sibling script has**
```
( cd "${SRC}" && GOMODCACHE="${SRC}/go-mod" go mod download -modcacherw )
XZ_OPT='-T0 -9' tar -C "${SRC}" -acf "${OUT}/local-ai-${VERSION}-deps.tar.xz" go-mod
```
`gen-zot` (26-29), `gen-dagu` (23-25) and `gen-gitea-runner` (22-29) all follow `go mod download` with `chmod -R u+w` plus `rm -rf .../golang.org/toolchain@* .../cache/download/golang.org/toolchain`, and document exactly why: LocalAI's go.mod requires go 1.26.0, so on a host with an older go, `GOTOOLCHAIN=auto` downloads a full toolchain into the module cache. Here it would be packed into the released `-deps.tar.xz` (hundreds of MB of non-dependency), and its read-only files break the `trap rm -rf` cleanup. Fix: lift the identical three lines in — see duplication finding D3, which fixes this and the duplication together.

**5. `scripts/check-updates.sh:47-49` and `:124-125` — `set -o pipefail` + `head -n1` makes the nightly job abort instead of warn**
```
open_issue() {
    curl -sf -H "${AUTH}" --get --data-urlencode "q=${1}" \
            --data 'state=open&type=issues' "${API}/issues" \
        | jq -r ... | head -n1
}
```
The script has a careful `warn:` + `rc=1` + `continue` path for every upstream lookup that fails — but `existing=$(open_issue ...)` has none, and under `set -euo pipefail` any `curl -sf` non-2xx (or a SIGPIPE to `jq` from `head` closing early) fails the pipeline, fails the assignment, and `set -e` kills the whole run — including the unrelated guru-sync and dep-bump checks below. Same shape at line 125 (`| grep -v 9999 | sort -V | tail -n1`: `grep -v` exits 1 when every ebuild is a 9999). Fix: `... | head -n1 || true` on the function's final pipeline, and let the existing `[ -z ... ]` emptiness checks do the reporting.

---

## SHOULD-FIX — duplication that belongs in the eclasses/scripts

**D1. The 12 `app-local-ai/*/files/run.sh` files are two templates with a substitution — and `local-ai-python.eclass` already shows the fix.**
Nine of them (crispasr, depth-anything, parakeet-cpp, qwen3-tts-cpp, rfdetr-cpp, stablediffusion-ggml, vibevoice-cpp, vllm-cpp, whisper) differ only in the env-var name and the library/binary name:
```
<VAR>="${CURDIR}/<lib>"; export <VAR>; exec "${CURDIR}/<PN>" "$@"
```
Three more (audio-cpp, bonsai, llama-cpp) are **byte-identical** `LD_LIBRARY_PATH` + `exec grpc-server` scripts; piper is that same template plus `ESPEAK_NG_DATA`.
`local-ai-ggml-go.eclass` already owns `LOCAL_AI_ENGINE_LIB` and `${PN}` — add a `LOCAL_AI_ENGINE_LIB_ENV` variable and generate run.sh in `local-ai-ggml-go_src_install` exactly the way `local-ai-python_install_meta` (`local-ai-python.eclass:132-148`) already generates its own. That deletes 9 FILESDIR files; a second small helper in `local-ai-backend.eclass` (`local-ai-backend_write_ldpath_run_sh`) deletes 3 more. This is the single largest remaining duplication and the pattern is already established in the overlay.

**D2. The four maturin/crates ebuilds carry a byte-identical `src_prepare`.**
`dev-python/safetensors:41-54`, `dev-python/tokenizers:42-54`, `dev-python/ormsgpack:34-46`, `dev-python/hf-xet:43-55` are the same cargo-vendor block verbatim, on top of an identical `RUST_MIN_VER`/`DISTUTILS_EXT`/`DISTUTILS_USE_PEP517=maturin`/`PYTHON_COMPAT` preamble and the same `CRATES_BASE=".../<pn>-v${PV}"` construction. Extract a `local-ai-crates.eclass` providing the `CRATES_BASE` + SRC_URI fragment and an exported `src_prepare`. (Worth evaluating ::gentoo's `cargo.eclass` with `CARGO_OPTIONAL=1` + `cargo_gen_config` first — it does exactly this natively and would also give you `ECARGO_HOME` handling for free.)

**D3. `gen-{zot,dagu,gitea-runner}-distfiles.sh` share an identical Go-module-cache block.** The five lines (`GOTOOLCHAIN` export, `go mod download -modcacherw`, `chmod -R u+w`, toolchain `rm -rf`, `tar`) are repeated three times and *incorrectly omitted* a fourth (bug 4). Extract `scripts/gen-go-deps.sh <srcdir> <outfile>` — the same move that produced `gen-rust-crates.sh`, which is already the model for this.

**D4. `gen-diffusers-distfiles.sh:28-35` and `gen-fish-speech-distfiles.sh:80-87` share the wheel-building block verbatim.** Extract `scripts/gen-wheels.sh <name> <version> <pkg>...`, leaving each caller as just its `PACKAGES` list and its explanatory header.

**D5. `app-local-ai/llama-cpp` and `app-local-ai/bonsai` are ~80% the same ebuild.** Identical `LOCAL_AI_EXTRA_CMAKE_ARGS` (14-18 / 22-26), identical `RDEPEND+=`/`DEPEND+=`/`BDEPEND+=` blocks (41-58 / 52-69), identical `IUSE="test"` + `RESTRICT`, identical `src_configure`, `src_test`, and the `bump_cxx20` + `prepare.sh` + `local-ai-ggml_src_prepare` tail. Bonsai's only real deltas are the `rm -rf patches`, the two `disable-*-task.sh` calls and `apply-patches.sh`. A `local-ai-llama-glue.eclass` (or a `LOCAL_AI_LLAMA_GLUE=1` knob on `local-ai-ggml`) owning the deps, the cmake args, the test wiring and a `local-ai-llama_prepare_glue` helper would leave two short ebuilds.

**D6. `parakeet-cpp:55-66` and `rfdetr-cpp:50-63` share the ggml-patches replay.** Same `pushd <engine>/third_party/ggml` + `eapply .../third_party/ggml-patches/*.patch` + `popd`. Add `local-ai-ggml_apply_engine_ggml_patches <engine-root>` to `local-ai-ggml.eclass`; rfdetr keeps only its extra `apply_ggml_patches.sh` no-op stub.

**D7. The family→package-directory registry exists in three places.** `cleanup-releases.yml:27` (`FAMILIES` assoc array), `release-distfiles.yml:33-46` (`case` statement) and, partially, `check-updates.sh:20-26`. They agree today but will drift on the next new family. Put one `scripts/families.sh` (an assoc array) and `source` it from both workflow steps.

**D8. `/usr/libexec/local-ai/python-common` is hardcoded in three places.** `app-local-ai/python-common:33`, `local-ai-python.eclass:138` (the generated run.sh) and `:155` (the smoke test, which uses `${EPREFIX}`-prefixed form while the other two don't). Add `LOCAL_AI_PYTHON_COMMON_DIR` next to `LOCAL_AI_BACKENDS_DIR` in `local-ai-backend.eclass`. Related: `local-ai-python.eclass:63` defines `BACKEND_DIR="/usr/libexec/local-ai/backends/${PN}"`, re-deriving what `LOCAL_AI_BACKENDS_DIR` already holds — use `"${LOCAL_AI_BACKENDS_DIR#${EPREFIX}}/${PN}"` instead.

---

## SHOULD-FIX — correctness and robustness

**S1. `app-local-ai/backends-meta:23-37` and `sci-ml/local-ai:52` — unversioned inter-package atoms.**
`backends-meta-4.9.0` depends on `app-local-ai/llama-cpp` (any version), and `local-ai`'s `PDEPEND` on `app-local-ai/backends-meta` (any version). Backends are built against one LocalAI release's `backend.proto` and are versioned in lockstep, so a stale 4.8.2 backend satisfies a 4.9.0 meta package. `local-ai-python.eclass:71` already gets this right (`~app-local-ai/python-common-${PV}`). Use `~app-local-ai/<pn>-${PV}` throughout, and likewise tighten the `sci-ml/local-ai` atom in `local-ai-ggml.eclass:75`, `local-ai-python.eclass:70`, `audio-cpp:35`, `vllm-cpp:41`, `piper:44`, `python-common:28` to `~sci-ml/local-ai-${PV}` (which matches any `-rN`, so the `-r7` server still satisfies it).

**S2. `scripts/gen-python-common-distfiles.sh:21` — relative path out of the CWD.**
```
recorded=$(grep -h "^DIST local-ai-${VERSION}.tar.gz " ../app-local-ai/*/Manifest | ...)
```
This works *only* because `release-distfiles.yml:27-28` happens to `cd distfiles-out` before invoking it. Every other script in `scripts/` is CWD-agnostic. Derive the repo root from `$0` as `gen-safetensors-distfiles.sh:3` already does:
```
REPO=$(dirname "$(dirname "$(realpath "$0")")")
... "$REPO"/app-local-ai/*/Manifest
```

**S3. `.gitea/workflows/release-distfiles.yml:34` — a `local-ai` release re-manifests the entire overlay.**
```
local-ai) DIRS=$(dirname $(find . -path ./distfiles-out -prune -o -name '*.ebuild' -print) | sort -u) ;;
```
This matches *every* package directory — zot, dagu, opencode, av, onnxruntime, hipSOLVER — so a LocalAI distfiles release regenerates and commits Manifests for unrelated packages, refetching all their distfiles, and fails the whole job if any single unrelated upstream is unreachable. Restrict to the packages that actually consume the local-ai distfiles: `DIRS="sci-ml/local-ai $(echo app-local-ai/*)"`.

**S4. `.gitea/workflows/release-distfiles.yml:55-56` — the acknowledged push race is still lost.**
```
git pull --rebase origin master
git push origin HEAD:master
```
A sibling job pushing between these two lines makes the push fail and the job red, losing the Manifest commit. Wrap in a bounded retry:
```
for i in 1 2 3 4 5; do git pull --rebase origin master && git push origin HEAD:master && break; sleep $((i*5)); done
```

**S5. `app-local-ai/piper:133` — install failure swallowed.**
```
doexe "${GOPIPER}"/espeak/ei/lib/lib*.so* 2>/dev/null || true
```
If the espeak build layout moves, the package installs successfully without its espeak libraries and only fails at the user's first TTS request. Make the optionality explicit and loud about the unexpected case:
```
local espeak_libs=( "${GOPIPER}"/espeak/ei/lib/lib*.so* )
[[ -e ${espeak_libs[0]} ]] && doexe "${espeak_libs[@]}"
```
Related, `:131`: `rm -f ...libonnxruntime.so* || die` can never fail — `rm -f` on a non-matching glob returns 0 — so it does not verify the bundled copy was actually there. A `[[ -e ]]` guard would.

**S6. `app-containers/zot:93` — missing `|| die`.** `rm -rf pkg/extensions/build` is the only unchecked command in the file; the very next line has `|| die`.

**S7. `scripts/gen-zot-distfiles.sh:24` vs `app-containers/zot:18` — the zui pin can drift silently.** The script *derives* `ZUI_PIN` from zot's Makefile; the ebuild *hardcodes* `ZUI_PIN="commit-a7feb46"`. If they disagree at a bump, the released `node_modules` tarball is installed into a different zui checkout with no error. Have the script echo the derived pin prominently (and assert it is non-empty — an empty `ZUI_PIN` currently produces a bare `.../tags/.tar.gz` fetch). Same class: `gen-dagu-distfiles.sh:33` does not check `PNPM` is non-empty before `npx -y "${PNPM}"`.

**S8. `gen-diffusers-distfiles.sh:33` / `gen-fish-speech-distfiles.sh:85` — no purity assertion on the built wheels.** `local-ai-python.eclass` supports `python3_{12..14}` and installs the wheels tarball offline with `--no-deps` into whichever venv the user's `PYTHON_SINGLE_TARGET` selects. That is only safe if every wheel is `-py3-none-any.whl`; `pip wheel` on the generator host will happily produce an ABI-tagged wheel if any entry gains a C extension, and it would then install into the wrong interpreter (or not at all) with the failure surfacing only in the build-time smoke test. Add after the loop:
```
for w in "$WORK"/wheels/*.whl; do
    case "$w" in *-py3-none-any.whl|*-py2.py3-none-any.whl) ;; *) echo "non-pure wheel: $w" >&2; exit 1 ;; esac
done
```

---

## NICE-TO-HAVE

- **`sci-ml/torchaudio/*:45-46` and `dev-python/numba:38` — the `-j1` argument is silently discarded.** `distutils-r1_python_compile` only forwards `"$@"` on the legacy non-PEP517 `esetup.py build` path; under `DISTUTILS_USE_PEP517` (both of these) the body never references `"$@"`. The parallelism is entirely controlled by `MAX_JOBS`, so the `-j1` reads as a guarantee it does not provide — drop it or comment it.
- **`eclass/local-ai-torch.eclass:108` — `local -x HIP_CLANG_PATH=$(hipconfig --hipclangpath)` has no `|| die`.** A failing `hipconfig` yields an empty value and LoadHIP silently falls back to `ROCM_PATH/lib/llvm/bin`, defeating the whole point of the export documented just above it. Assign, then check non-empty and die.
- **`eclass/local-ai-torch.eclass:82` — `rocm_add_sandbox -w` runs unconditionally**, including on non-ROCm builds. Guard with `use rocm &&` for symmetry with the `use cuda &&` on the next line.
- **`export` where `local -x` would do:** `local-ai-torch.eclass:103` (`BUILD_VERSION`), `torchaudio:40-43`, `numba:37`, `llvmlite:32-36`, `torchcodec:89`. These leak into the saved phase environment; the eclass's own rocm block at `:106-108` already uses `local -x` and is the better model.
- **`eclass/local-ai-ggml.eclass:106` — `use cuda && cuda_src_prepare` as the last command** makes `src_prepare` return 1 on non-CUDA builds. Portage ignores it, but `use cuda && cuda_src_prepare; return 0` (or an `if`) avoids the trap if the function is ever composed.
- **Redundant phase redefinitions:** `audio-cpp:96-98` (`src_compile`), and `src_test() { cmake_src_test; }` in `llama-cpp:89-91`, `bonsai:107-109`, `audio-cpp:100-102`. `cmake.eclass` already exports both; `local-ai-ggml`'s later `EXPORT_FUNCTIONS` does not list `src_test`, so the inherited one survives.
- **`dev-python/av/av-18.1.0.ebuild:15` — the DESCRIPTION begins with two U+FEFF (BOM) characters** (`ef bb bf ef bb bf` before "Pythonic"). Inherited from the GURU 17.x ebuilds, but 18.1.0 is original work; strip them.
- **`dev-python/av/av-18.1.0.ebuild:22-30` — dead `*9999` branch.** There is no live ebuild in this overlay; the `git-r3` inherit and `EGIT_REPO_URI` are unreachable.
- **`eclass/local-ai-backend.eclass:30` and `sci-ml/local-ai:77` still name `scripts/gen-distfiles.sh`**, which is now `scripts/gen-local-ai-distfiles.sh`. `.gitignore:6` has the same stale name.
- **`profiles/updates/3Q-2026` has no `move app-local-ai/backends app-local-ai/backends-meta`** — the local metadata cache still carries an `app-local-ai/backends-4.9.0` entry, so the rename happened; anyone who installed the old name gets an orphan.
- **KEYWORDS handling is inconsistent between the two backend eclasses.** `local-ai-python.eclass:60` sets `KEYWORDS="~amd64"` for its consumers; `local-ai-ggml.eclass` does not, so all 11 ggml ebuilds repeat the line. Pick one (repeating it in the ebuild is the more ::gentoo-idiomatic choice, in which case drop it from the python eclass).
- **`scripts/gen-opencode-distfiles.sh:30-31` — `find | sed > list; tar -T list`** breaks on any path containing a newline. `find -print0` + `tar --null -T -` is the safe form.
- **`.gitea/workflows/cleanup-releases.yml:51-52` — `curl -s -X DELETE` without `-f`** silently ignores failed tag deletions, while the release deletion one line above uses `-sf`. Also worth an explicit comment that the *scheduled* run always deletes for real (`DRY_RUN` resolves to `'false'` on `schedule`) while manual runs default to dry-run — that asymmetry is deliberate but invisible.
- **`eclass/local-ai-python.eclass:155-158` — consider `PYTHONDONTWRITEBYTECODE=1` on the smoke test.** It runs after `python_optimize`, so any module it imports that the optimize pass missed drops fresh `__pycache__` files into `${D}` that then ship untracked by the byte-compile QA check.
- **`dev-python/soxr` declares no tests at all** — neither `distutils_enable_tests` nor `RESTRICT="test"`. Every other python package in the overlay makes the choice explicit with a comment; this one is silent.

---

## Out of scope, noted

`sci-libs/hipSOLVER/hipSOLVER-7.2.0.ebuild` is a byte-verbatim copy of ::gentoo's ebuild plus a nine-line header comment (I diffed it) — the actual fix lives in `files/hipSOLVER-7.0.1-find-cholmod.patch`. It reads as a tree mirror like the excluded GURU copies, so I did not review it as original work; you may want to add it to the documented exclusion list.
