# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Fine-tune and post-train LLMs from one YAML (LoRA/QLoRA, SFT, DPO and
# friends), with GGUF export for serving via LocalAI. Ships upstream's
# [train] stack unconditionally — the base CLI cannot fine-tune and is
# not worth a flag. Every dependency is a tree or overlay package (no
# venv); bitsandbytes is parked (prebuilt-binary wheel, no source
# package yet): the 4bit/8bit quantization paths import it lazily and
# fail cleanly; the rest works.

EAPI=8

DISTUTILS_USE_PEP517=hatchling
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1

DESCRIPTION="Fine-tune and post-train LLMs in one command"
HOMEPAGE="https://trysoup.dev https://github.com/MakazhanAlpamys/Soup"
# The PyPI sdist: releases land there first (GitHub main can lag a
# patch release behind).
SRC_URI="https://files.pythonhosted.org/packages/source/s/soup-cli/soup_cli-${PV}.tar.gz"
S="${WORKDIR}/soup_cli-${PV}"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="test"

RDEPEND="
	sci-ml/accelerate[${PYTHON_SINGLE_USEDEP}]
	sci-ml/datasets[${PYTHON_SINGLE_USEDEP}]
	sci-ml/huggingface_hub[${PYTHON_SINGLE_USEDEP}]
	sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]
	>=sci-ml/transformers-5.16.1[${PYTHON_SINGLE_USEDEP}]
	dev-python/peft[${PYTHON_SINGLE_USEDEP}]
	dev-python/trl[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/packaging[${PYTHON_USEDEP}]
		dev-python/plotext[${PYTHON_USEDEP}]
		dev-python/pydantic[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/rich[${PYTHON_USEDEP}]
		dev-python/typer[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"

src_prepare() {
	distutils-r1_src_prepare

	# Upstream caps typer at <0.21 as a CI-matrix precaution; the tree's
	# 0.27 passes the full CLI surface (command tree, subcommands —
	# verified 2026-09-28). Relaxing the pin here also fixes the
	# installed metadata, so `soup env check` sees clean bounds.
	sed -i 's/"typer>=0.9.0,<0.21.0",/"typer>=0.9.0",/' pyproject.toml || die
	grep -q '"typer>=0.9.0",' pyproject.toml || die "typer pin relax did not apply"

	# Upstream caps requires-python at <3.13 to keep pip users inside its
	# CI-tested torch-wheel matrix (loader crashes in libc10.so on
	# untested interpreters, upstream #358). That hazard does not exist
	# here: sci-ml/pytorch is built from source for the active python.
	sed -i 's/requires-python = ">=3.10,<3.13"/requires-python = ">=3.10"/' pyproject.toml || die
	grep -q 'requires-python = ">=3.10"' pyproject.toml || die "requires-python relax did not apply"
}

pkg_postinst() {
	elog "QLoRA (quantization: 4bit/8bit) needs bitsandbytes, which is not"
	elog "packaged yet (prebuilt-binary wheel; a source-built package is"
	elog "planned). LoRA, SFT and the preference trainers work without it."
}
