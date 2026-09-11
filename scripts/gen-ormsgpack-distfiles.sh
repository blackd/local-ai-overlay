#!/bin/bash
set -euo pipefail
bash "$(dirname "$(realpath "$0")")/gen-rust-crates.sh" ormsgpack "${1:?usage: gen-ormsgpack-distfiles.sh <version>}" .
