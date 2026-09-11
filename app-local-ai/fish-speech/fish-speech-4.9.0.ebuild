# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI TTS backend (fish-speech / OpenAudio). Upstream's install
# clones fish-speech from UNPINNED git main at install time; we pin
# the release tag below and install the source next to backend.py.
# The venv follows the python-backend parity rule: everything
# upstream's install resolves (the full pyproject — train and webui
# extras included) ships, with tree/overlay-provided packages arriving
# through --system-site-packages instead of wheels. Upstream's own
# install deviations are replicated: torch/torchaudio pins stripped,
# pyaudio dropped, protobuf 5 (system) overriding audiotools' stale
# <3.20 pin. Our one additional deviation: pydantic==2.9.2 relaxed to
# the tree pydantic (resolution- and API-verified; the tree package
# builds pydantic_core in-package). wandb and tensorboard-data-server
# are pending (prebuilt binaries in their wheels). Shared helpers and
# gRPC stubs come from app-local-ai/python-common.

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )

inherit local-ai-backend python-single-r1

# The newest fish-speech release; matches the module layout backend.py
# imports (inference_engine, models.dac, models.text2semantic).
FISH_SPEECH_TAG="v2.0.0-beta"

FISH_SPEECH_DISTFILES="https://git.ipnmod.org/packages/local-ai-overlay/releases/download/fish-speech-v${PV}"

DESCRIPTION="LocalAI text-to-speech backend (fish-speech gRPC server)"
SRC_URI="
	${LOCAL_AI_SRC_URI}
	https://github.com/fishaudio/fish-speech/archive/refs/tags/${FISH_SPEECH_TAG}.tar.gz
		-> fish-speech-${FISH_SPEECH_TAG}.gh.tar.gz
	${FISH_SPEECH_DISTFILES}/fish-speech-${PV}-wheels.tar.xz
"
S="${WORKDIR}/LocalAI-${PV}/backend/python/fish-speech"
FISH_S="${WORKDIR}/fish-speech-${FISH_SPEECH_TAG#v}"

LICENSE="MIT Apache-2.0 Fish-Audio-Research"
SLOT="0"
KEYWORDS="~amd64"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="${PYTHON_DEPS}
	sci-ml/local-ai
	~app-local-ai/python-common-${PV}
	$(python_gen_cond_dep '
		sci-ml/pytorch[${PYTHON_SINGLE_USEDEP}]
		sci-ml/torchaudio[${PYTHON_SINGLE_USEDEP}]
		app-arch/brotli[python,${PYTHON_USEDEP}]
		dev-python/hf-xet[${PYTHON_USEDEP}]
		dev-python/llvmlite[${PYTHON_USEDEP}]
		dev-python/numba[${PYTHON_USEDEP}]
		dev-python/ormsgpack[${PYTHON_USEDEP}]
		dev-python/safetensors[${PYTHON_USEDEP}]
		dev-python/soxr[${PYTHON_USEDEP}]
		dev-python/tiktoken[${PYTHON_USEDEP}]
		dev-python/tokenizers[${PYTHON_USEDEP}]
		>=dev-python/grpcio-1.76.0[${PYTHON_USEDEP}]
		dev-python/absl-py[${PYTHON_USEDEP}]
		dev-python/aiohappyeyeballs[${PYTHON_USEDEP}]
		dev-python/aiohttp[${PYTHON_USEDEP}]
		dev-python/aiosignal[${PYTHON_USEDEP}]
		dev-python/annotated-doc[${PYTHON_USEDEP}]
		dev-python/annotated-types[${PYTHON_USEDEP}]
		dev-python/antlr4-python3-runtime[${PYTHON_USEDEP}]
		dev-python/anyio[${PYTHON_USEDEP}]
		dev-python/asttokens[${PYTHON_USEDEP}]
		dev-python/attrs[${PYTHON_USEDEP}]
		dev-python/cachetools[${PYTHON_USEDEP}]
		dev-python/certifi[${PYTHON_USEDEP}]
		dev-python/cffi[${PYTHON_USEDEP}]
		dev-python/charset-normalizer[${PYTHON_USEDEP}]
		dev-python/click[${PYTHON_USEDEP}]
		dev-python/cloudpickle[${PYTHON_USEDEP}]
		dev-python/contourpy[${PYTHON_USEDEP}]
		dev-python/cycler[${PYTHON_USEDEP}]
		dev-python/decorator[${PYTHON_USEDEP}]
		dev-python/dill[${PYTHON_USEDEP}]
		dev-python/docstring-parser[${PYTHON_USEDEP}]
		dev-python/executing[${PYTHON_USEDEP}]
		dev-python/fastapi[${PYTHON_USEDEP}]
		dev-python/filelock[${PYTHON_USEDEP}]
		dev-python/fonttools[${PYTHON_USEDEP}]
		dev-python/frozenlist[${PYTHON_USEDEP}]
		dev-python/fsspec[${PYTHON_USEDEP}]
		dev-python/gitdb[${PYTHON_USEDEP}]
		dev-python/gitpython[${PYTHON_USEDEP}]
		dev-python/h11[${PYTHON_USEDEP}]
		dev-python/httpcore[${PYTHON_USEDEP}]
		dev-python/httpx[${PYTHON_USEDEP}]
		dev-python/idna[${PYTHON_USEDEP}]
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
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/orjson[${PYTHON_USEDEP}]
		dev-python/packaging[${PYTHON_USEDEP}]
		dev-python/pandas[${PYTHON_USEDEP}]
		dev-python/parso[${PYTHON_USEDEP}]
		dev-python/pexpect[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/platformdirs[${PYTHON_USEDEP}]
		dev-python/pooch[${PYTHON_USEDEP}]
		dev-python/prompt-toolkit[${PYTHON_USEDEP}]
		dev-python/propcache[${PYTHON_USEDEP}]
		dev-python/protobuf[${PYTHON_USEDEP}]
		dev-python/psutil[${PYTHON_USEDEP}]
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
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/regex[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
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
		dev-python/tqdm[${PYTHON_USEDEP}]
		dev-python/traitlets[${PYTHON_USEDEP}]
		dev-python/typer[${PYTHON_USEDEP}]
		dev-python/typing-extensions[${PYTHON_USEDEP}]
		dev-python/typing-inspection[${PYTHON_USEDEP}]
		dev-python/urllib3[${PYTHON_USEDEP}]
		dev-python/uvicorn[${PYTHON_USEDEP}]
		dev-python/wcwidth[${PYTHON_USEDEP}]
		dev-python/werkzeug[${PYTHON_USEDEP}]
		dev-python/xxhash[${PYTHON_USEDEP}]
		dev-python/yarl[${PYTHON_USEDEP}]
		dev-python/zstandard[${PYTHON_USEDEP}]
	')
	$(python_gen_cond_dep 'dev-python/audioop-lts[${PYTHON_USEDEP}]' python3_{13..14})
"
# Build-time too: the import smoke test at the end of src_install runs
# the backend's whole import closure.
DEPEND="${RDEPEND}"

BACKEND_DIR="/usr/libexec/local-ai/backends/fish-speech"

src_unpack() {
	unpack "local-ai-${PV}.tar.gz" "fish-speech-${FISH_SPEECH_TAG}.gh.tar.gz" "fish-speech-${PV}-wheels.tar.xz"
}

src_compile() {
	# The Makefile here drives upstream's uv-based image install,
	# which the offline venv assembled in src_install replaces.
	:
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

	"${EPYTHON}" -m venv --system-site-packages "${ED}${BACKEND_DIR}/venv" || die
	"${ED}${BACKEND_DIR}/venv/bin/python" -m pip install \
		--no-index --find-links "${WORKDIR}/wheels" --no-deps --no-compile \
		"${WORKDIR}"/wheels/*.whl || die
	# The venv's paths must not remember the image root.
	find "${ED}${BACKEND_DIR}/venv/bin" -type f -exec sed -i "s:${D}::g" {} + || die
	python_optimize "${ED}${BACKEND_DIR}/venv/lib" "${ED}${BACKEND_DIR}/fish_speech"

	local-ai-backend_install_meta fish-speech

	# Import smoke test. backend.py imports fish_speech lazily at
	# LoadModel, so importing it alone would prove nothing — exercise
	# the real inference closure explicitly, at build time.
	PYTHONPATH="${ED}${BACKEND_DIR}:${EPREFIX}/usr/libexec/local-ai/python-common" \
		"${ED}${BACKEND_DIR}/venv/bin/python" -c "
import backend
import fish_speech.inference_engine
import fish_speech.models.dac.inference
import fish_speech.models.text2semantic.inference
import fish_speech.utils.schema" \
		|| die "backend import check failed"
}
