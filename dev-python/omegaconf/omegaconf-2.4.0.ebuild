# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Hierarchical YAML/dataclass configuration library (the Hydra
# ecosystem), a dependency of several LocalAI python backends.
# Upstream's setup.py swaps build_py for a command that deletes the
# shipped grammar parsers and regenerates them by running a prebuilt
# antlr-4.11.1-complete.jar out of the sdist, against an ANTLR python
# runtime vendored as omegaconf.vendor.antlr4. Neither is used here:
# the jar and the vendored runtime are removed, the parsers are
# regenerated with dev-java/antlr:4 and the package imports the system
# dev-python/antlr4-python3-runtime of the same version.

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="A flexible configuration library"
HOMEPAGE="https://github.com/hydra-ecosystem/omegaconf https://pypi.org/project/omegaconf/"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

# Generated parsers and the runtime must be the same ANTLR minor.
RDEPEND="
	dev-python/pyyaml[${PYTHON_USEDEP}]
	=dev-python/antlr4-python3-runtime-4.13*[${PYTHON_USEDEP}]
"
BDEPEND="
	=dev-java/antlr-4.13*:4
	test? (
		dev-python/attrs[${PYTHON_USEDEP}]
		dev-python/pytest-mock[${PYTHON_USEDEP}]
	)
"

distutils_enable_tests pytest

# Repository-maintenance tests: the release workflow helper and an
# npm dependency audit script that live outside the sdist's package.
EPYTEST_IGNORE=(
	tests/test_release_workflow.py
	tests/test_dependency_audit.py
	tests/test_dependency_audit_invariants.py
	tests/test_dependency_audit_pnpm.py
	tests/test_dependency_audit_repairs.py
	tests/test_dependency_audit_workflow.py
)

src_prepare() {
	distutils-r1_src_prepare

	# The bundled ANTLR tool jar and the vendored python runtime.
	rm -r build_helpers/bin omegaconf/vendor || die

	# Stock build_py: no clean step, no jar run.
	sed -i -e '/"build_py": BuildPyCommand,/d' -e '/"clean": CleanCommand,/d' setup.py || die
	grep -q '"build_py": BuildPyCommand' setup.py && die "build_py override still registered"

	# The three hand-written modules that import the vendored runtime.
	sed -i 's/from \.vendor\.antlr4/from antlr4/' omegaconf/grammar_parser.py omegaconf/grammar_visitor.py omegaconf/typing.py || die
	grep -rq 'vendor' omegaconf/*.py && die "vendored antlr4 import left behind"

	# Regenerate the parsers with the system tool, lexer first so the
	# parser grammar finds its tokens file. The tool emits plain
	# "from antlr4 import *" imports, which is what we want.
	rm omegaconf/grammar/gen/OmegaConfGrammar*.py || die
	antlr4 -Dlanguage=Python3 -o omegaconf/grammar/gen -Xexact-output-dir -visitor omegaconf/grammar/OmegaConfGrammarLexer.g4 || die
	antlr4 -Dlanguage=Python3 -o omegaconf/grammar/gen -Xexact-output-dir -visitor omegaconf/grammar/OmegaConfGrammarParser.g4 || die
}
