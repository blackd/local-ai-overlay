# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI reranking backend (the /rerank endpoint, cross-encoder
# relevance scoring for RAG): the rerankers library with its
# transformers backend. The venv skeleton lives in
# local-ai-python.eclass; the wheels tarball carries a single wheel
# (rerankers itself, built from its sdist) — every other dependency is
# a tree package.

EAPI=8

LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend rerankers"

inherit local-ai-python

DESCRIPTION="LocalAI reranking backend (rerankers gRPC server)"

LICENSE="MIT Apache-2.0"

RDEPEND+="
	sci-ml/accelerate[${PYTHON_SINGLE_USEDEP}]
	sci-ml/huggingface_hub[${PYTHON_SINGLE_USEDEP}]
	>=sci-ml/transformers-5.16.1[${PYTHON_SINGLE_USEDEP}]
	$(python_gen_cond_dep '
		dev-python/annotated-doc[${PYTHON_USEDEP}]
		dev-python/rich[${PYTHON_USEDEP}]
		dev-python/typer[${PYTHON_USEDEP}]
		sci-ml/sentencepiece[${PYTHON_USEDEP}]
	')
"
DEPEND="${RDEPEND}"
