# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: local-ai-rocm.eclass
# @MAINTAINER:
# Plamen K. Kosseff
# @SUPPORTED_EAPIS: 8
# @PROVIDES: rocm
# @BLURB: Overlay-wide ROCm version pin feeding the rocm eclass
# @DESCRIPTION:
# The single place the overlay's ROCm toolchain generation is declared.
# Sets ROCM_VERSION — which keys the rocm eclass's amdgpu_targets_*
# IUSE list (Portage filters the AMDGPU_TARGETS env var to flags
# present in IUSE, so a package without the eclass globals gets an
# empty get_amdgpu_flags) — before inheriting rocm, so every
# ROCm-capable package, ggml backends and the sci-ml torch stack
# alike, follows the same version. Bump it HERE when the system ROCm
# moves.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_LOCAL_AI_ROCM_ECLASS} ]]; then
_LOCAL_AI_ROCM_ECLASS=1

# @ECLASS_VARIABLE: ROCM_VERSION
# @DESCRIPTION:
# ROCm toolchain version the rocm eclass targets; overlay packages
# also use it as the floor for their HIP/BLAS runtime dependencies.
ROCM_VERSION=7.2

inherit rocm

fi
