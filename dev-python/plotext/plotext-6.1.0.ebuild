# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Derived from GURU's plotext-5.3.2 (GURU has no 6.x yet); plotext 6
# replaced the module-level plotting API with Figure methods, and
# consumers here (sci-ml/soup-cli) support the 6.x surface.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

DESCRIPTION="Plotting on terminal"
HOMEPAGE="https://github.com/piccolomo/plotext"
SRC_URI="https://github.com/piccolomo/plotext/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="test"
