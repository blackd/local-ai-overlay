# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# cffi binding to PortAudio for playback and capture. The ABI-mode
# cffi builder generates a pure-python module at build time and the
# system libportaudio is dlopen'ed at import; nothing is compiled.
# The sdist bundles prebuilt Windows and macOS PortAudio libraries
# for those platforms' wheels. They are deleted in src_prepare.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Play and Record Sound with Python"
HOMEPAGE="https://python-sounddevice.readthedocs.io/ https://github.com/spatialaudio/python-sounddevice https://pypi.org/project/sounddevice/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
# No test-suite in the sdist.
RESTRICT="test"

RDEPEND="
	dev-python/cffi[${PYTHON_USEDEP}]
	media-libs/portaudio
"
BDEPEND="dev-python/cffi[${PYTHON_USEDEP}]"

src_prepare() {
	distutils-r1_src_prepare
	# Prebuilt PortAudio DLLs and dylib for the Windows and macOS wheels.
	rm -r src/_sounddevice_data || die
}
