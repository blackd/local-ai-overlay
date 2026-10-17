# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Aho-Corasick automaton as a C extension; textsearch's engine, reached
# through contractions by VoxCPM's text normaliser (wetext).

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_EXT=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Aho-Corasick automaton for efficient multi-pattern string search"
HOMEPAGE="https://github.com/WojciechMula/pyahocorasick"

LICENSE="BSD public-domain"
SLOT="0"
KEYWORDS="~amd64"

# Test layout not wired up.
RESTRICT="test"
