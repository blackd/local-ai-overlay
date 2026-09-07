#!/bin/bash
set -euo pipefail
bash "$(dirname "$(realpath "$0")")/gen-rust-crates.sh" safetensors "${1:?usage: gen-safetensors-distfiles.sh <version>}" bindings/python
