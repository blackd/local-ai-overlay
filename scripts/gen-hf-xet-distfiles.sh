#!/bin/bash
set -euo pipefail
bash "$(dirname "$(realpath "$0")")/gen-rust-crates.sh" hf-xet "${1:?usage: gen-hf-xet-distfiles.sh <version>}" .
