# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Tensor rearrangement notation for torch/numpy. Was a venv wheel of
# fish-speech and voxcpm, both at 0.8.2 — one system copy instead.
# No runtime dependencies.

EAPI=8

DISTUTILS_USE_PEP517=hatchling
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Flexible and powerful tensor operations for readable and reliable code"
HOMEPAGE="https://einops.rocks https://github.com/arogozhnikov/einops"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

# The test-suite exercises every supported framework (tf, jax, ...).
RESTRICT="test"
