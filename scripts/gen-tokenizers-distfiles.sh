#!/bin/bash
set -euo pipefail
bash "$(dirname "$(realpath "$0")")/gen-rust-crates.sh" tokenizers "${1:?usage: gen-tokenizers-distfiles.sh <version>}" bindings/python
