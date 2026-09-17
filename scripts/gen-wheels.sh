#!/bin/bash
# Shared helper for the python backends' venv wheels: build each given
# requirement into a wheel (pip wheel, not pip download — sdist-only
# packages like randomname/argbind must land as .whl for the ebuild's
# offline *.whl install), assert every result is a PURE wheel, and pack
# them as <family>-<version>-wheels.tar.xz in $PWD. Purity matters:
# local-ai-python.eclass installs the tarball with --no-deps into a venv
# for whichever python PYTHON_SINGLE_TARGET picked, which is only
# interpreter-portable for py3-none-any wheels; anything compiled
# belongs in a system package instead (system-deps-first policy).
set -euo pipefail

FAMILY="${1:?usage: gen-wheels.sh <family> <version> <package>...}"
VERSION="${2:?usage: gen-wheels.sh <family> <version> <package>...}"
shift 2
[ $# -gt 0 ] || { echo "no packages given" >&2; exit 1; }

WORK=$(mktemp -d /tmp/gen-wheels.XXXXXX)
OUT="$PWD"
trap 'rm -rf "$WORK"' EXIT

mkdir "$WORK/wheels"
for p in "$@"; do
	python3 -m pip wheel --no-deps --wheel-dir "$WORK/wheels" "$p"
done

for w in "$WORK"/wheels/*.whl; do
	case "$w" in
		*-py3-none-any.whl|*-py2.py3-none-any.whl) ;;
		*) echo "ERROR: non-pure wheel $(basename "$w") — belongs in a system package" >&2; exit 1 ;;
	esac
done

tar -C "$WORK" -cJf "$OUT/${FAMILY}-${VERSION}-wheels.tar.xz" wheels
echo "Created in $OUT:"
ls -lh "$OUT/${FAMILY}-${VERSION}-wheels.tar.xz"
