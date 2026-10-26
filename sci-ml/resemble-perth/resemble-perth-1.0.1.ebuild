# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Resemble AI's neural audio watermarker, applied by chatterbox and
# neutts to everything they synthesise. The pretrained PerthNet
# checkpoint ships inside the sdist as package data, so nothing is
# fetched at run time. setup.py reads its dependencies from a
# requirements.txt the sdist does not contain, hence the empty
# upstream metadata; RDEPEND below is the watermarker's and the CLI's
# import closure. perth.waveform (audioread, pydub, pyrubberband) is
# imported by nothing in the package and is left unsatisfied.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Audio Watermarking and Detection Library"
HOMEPAGE="https://github.com/resemble-ai/Perth https://pypi.org/project/resemble-perth/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]
	sci-ml/torchaudio[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/librosa[${PYTHON_USEDEP}]
		dev-python/matplotlib[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/scipy[${PYTHON_USEDEP}]
		dev-python/soundfile[${PYTHON_USEDEP}]
	')
"

# pkg_resources is gone from current setuptools.
PATCHES=( "${FILESDIR}/${P}-importlib-resources.patch" )

distutils_enable_tests pytest
