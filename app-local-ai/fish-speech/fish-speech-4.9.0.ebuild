# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI TTS backend (fish-speech / OpenAudio). Upstream's install
# clones fish-speech from UNPINNED git main at install time; we pin
# the release tag below and install the source next to backend.py.
# The venv skeleton lives in local-ai-python.eclass; the parity-rule
# resolution here additionally replicates upstream's own install
# deviations (torch/torchaudio pins stripped, pyaudio dropped,
# protobuf 5 from the system overriding audiotools' stale <3.20 pin)
# plus one of ours: pydantic==2.9.2 relaxed to the tree pydantic
# (resolution- and API-verified; the tree package builds pydantic_core
# in-package). wandb and tensorboard-data-server are pending (prebuilt
# binaries in their wheels).

EAPI=8

# backend.py imports fish_speech lazily at LoadModel — smoke-test the
# real inference closure.
LOCAL_AI_PYTHON_SMOKE_IMPORTS="backend
	fish_speech.inference_engine
	fish_speech.models.dac.inference
	fish_speech.models.text2semantic.inference
	fish_speech.utils.schema"

inherit local-ai-python

# The newest fish-speech release; matches the module layout backend.py
# imports (inference_engine, models.dac, models.text2semantic).
FISH_SPEECH_TAG="v2.0.0-beta"

DESCRIPTION="LocalAI text-to-speech backend (fish-speech gRPC server)"
SRC_URI+="
	https://github.com/fishaudio/fish-speech/archive/refs/tags/${FISH_SPEECH_TAG}.tar.gz
		-> fish-speech-${FISH_SPEECH_TAG}.gh.tar.gz
"
FISH_S="${WORKDIR}/fish-speech-${FISH_SPEECH_TAG#v}"

LICENSE="MIT Apache-2.0 Fish-Audio-Research"

RDEPEND+="
	$(python_gen_cond_dep '
		sci-ml/torchaudio[${PYTHON_SINGLE_USEDEP}]
		app-arch/brotli[python,${PYTHON_USEDEP}]
		dev-python/hf-xet[${PYTHON_USEDEP}]
		dev-python/llvmlite[${PYTHON_USEDEP}]
		dev-python/numba[${PYTHON_USEDEP}]
		dev-python/ormsgpack[${PYTHON_USEDEP}]
		dev-python/soxr[${PYTHON_USEDEP}]
		dev-python/tiktoken[${PYTHON_USEDEP}]
		dev-python/absl-py[${PYTHON_USEDEP}]
		dev-python/aiohappyeyeballs[${PYTHON_USEDEP}]
		dev-python/aiohttp[${PYTHON_USEDEP}]
		dev-python/aiosignal[${PYTHON_USEDEP}]
		dev-python/annotated-doc[${PYTHON_USEDEP}]
		dev-python/annotated-types[${PYTHON_USEDEP}]
		dev-python/antlr4-python3-runtime[${PYTHON_USEDEP}]
		dev-python/asttokens[${PYTHON_USEDEP}]
		dev-python/attrs[${PYTHON_USEDEP}]
		dev-python/cachetools[${PYTHON_USEDEP}]
		dev-python/cffi[${PYTHON_USEDEP}]
		dev-python/click[${PYTHON_USEDEP}]
		dev-python/cloudpickle[${PYTHON_USEDEP}]
		dev-python/contourpy[${PYTHON_USEDEP}]
		dev-python/cycler[${PYTHON_USEDEP}]
		dev-python/decorator[${PYTHON_USEDEP}]
		dev-python/dill[${PYTHON_USEDEP}]
		dev-python/docstring-parser[${PYTHON_USEDEP}]
		dev-python/executing[${PYTHON_USEDEP}]
		dev-python/fastapi[${PYTHON_USEDEP}]
		dev-python/fonttools[${PYTHON_USEDEP}]
		dev-python/frozenlist[${PYTHON_USEDEP}]
		dev-python/gitdb[${PYTHON_USEDEP}]
		dev-python/gitpython[${PYTHON_USEDEP}]
		dev-python/ipython[${PYTHON_USEDEP}]
		dev-python/ipython-pygments-lexers[${PYTHON_USEDEP}]
		dev-python/jedi[${PYTHON_USEDEP}]
		dev-python/jinja2[${PYTHON_USEDEP}]
		dev-python/joblib[${PYTHON_USEDEP}]
		dev-python/kiwisolver[${PYTHON_USEDEP}]
		dev-python/lazy-loader[${PYTHON_USEDEP}]
		dev-python/loguru[${PYTHON_USEDEP}]
		dev-python/markdown[${PYTHON_USEDEP}]
		dev-python/markdown-it-py[${PYTHON_USEDEP}]
		dev-python/markdown2[${PYTHON_USEDEP}]
		dev-python/markupsafe[${PYTHON_USEDEP}]
		dev-python/matplotlib[${PYTHON_USEDEP}]
		dev-python/matplotlib-inline[${PYTHON_USEDEP}]
		dev-python/mdurl[${PYTHON_USEDEP}]
		dev-python/mpmath[${PYTHON_USEDEP}]
		dev-python/msgpack[${PYTHON_USEDEP}]
		dev-python/multidict[${PYTHON_USEDEP}]
		dev-python/multiprocess[${PYTHON_USEDEP}]
		dev-python/narwhals[${PYTHON_USEDEP}]
		dev-python/natsort[${PYTHON_USEDEP}]
		dev-python/networkx[${PYTHON_USEDEP}]
		dev-python/orjson[${PYTHON_USEDEP}]
		dev-python/pandas[${PYTHON_USEDEP}]
		dev-python/parso[${PYTHON_USEDEP}]
		dev-python/pexpect[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/platformdirs[${PYTHON_USEDEP}]
		dev-python/pooch[${PYTHON_USEDEP}]
		dev-python/prompt-toolkit[${PYTHON_USEDEP}]
		dev-python/propcache[${PYTHON_USEDEP}]
		dev-python/ptyprocess[${PYTHON_USEDEP}]
		dev-python/pure-eval[${PYTHON_USEDEP}]
		dev-python/pyarrow[${PYTHON_USEDEP}]
		dev-python/pycparser[${PYTHON_USEDEP}]
		dev-python/pydantic[${PYTHON_USEDEP}]
		dev-python/pygments[${PYTHON_USEDEP}]
		dev-python/pyparsing[${PYTHON_USEDEP}]
		dev-python/python-dateutil[${PYTHON_USEDEP}]
		dev-python/python-dotenv[${PYTHON_USEDEP}]
		dev-python/python-multipart[${PYTHON_USEDEP}]
		dev-python/pytz[${PYTHON_USEDEP}]
		dev-python/rich[${PYTHON_USEDEP}]
		dev-python/scikit-learn[${PYTHON_USEDEP}]
		dev-python/scipy[${PYTHON_USEDEP}]
		dev-python/semantic-version[${PYTHON_USEDEP}]
		dev-python/setuptools[${PYTHON_USEDEP}]
		dev-python/shellingham[${PYTHON_USEDEP}]
		dev-python/six[${PYTHON_USEDEP}]
		dev-python/smmap[${PYTHON_USEDEP}]
		dev-python/soundfile[${PYTHON_USEDEP}]
		dev-python/stack-data[${PYTHON_USEDEP}]
		dev-python/starlette[${PYTHON_USEDEP}]
		dev-python/sympy[${PYTHON_USEDEP}]
		dev-python/termcolor[${PYTHON_USEDEP}]
		dev-python/threadpoolctl[${PYTHON_USEDEP}]
		dev-python/tomlkit[${PYTHON_USEDEP}]
		dev-python/traitlets[${PYTHON_USEDEP}]
		dev-python/typer[${PYTHON_USEDEP}]
		dev-python/typing-inspection[${PYTHON_USEDEP}]
		dev-python/uvicorn[${PYTHON_USEDEP}]
		dev-python/wcwidth[${PYTHON_USEDEP}]
		dev-python/werkzeug[${PYTHON_USEDEP}]
		dev-python/xxhash[${PYTHON_USEDEP}]
		dev-python/yarl[${PYTHON_USEDEP}]
		dev-python/zstandard[${PYTHON_USEDEP}]
	')
	$(python_gen_cond_dep 'dev-python/audioop-lts[${PYTHON_USEDEP}]' python3_{13..14})
"
DEPEND="${RDEPEND}"

src_unpack() {
	local-ai-python_src_unpack
	unpack "fish-speech-${FISH_SPEECH_TAG}.gh.tar.gz"
}

src_install() {
	exeinto "${BACKEND_DIR}"
	doexe backend.py

	# The pinned fish-speech source, importable next to backend.py
	# (python puts the script's directory on sys.path). Installed
	# UNMODIFIED, whole tree — no behaviour trimming.
	insinto "${BACKEND_DIR}"
	doins -r "${FISH_S}/fish_speech"
	# pyrootutils walks up to this marker; upstream's install.sh
	# creates the same file.
	touch "${T}/.project-root" || die
	doins "${T}/.project-root"

	local-ai-python_install_venv
	python_optimize "${ED}${BACKEND_DIR}/fish_speech"
	local-ai-python_install_meta
	local-ai-python_smoke_test
}
