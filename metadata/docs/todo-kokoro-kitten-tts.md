# kokoro and kitten-tts backends: findings and open work

Status as of 2026-10-28. Both LocalAI backends are text-to-speech engines
that share one Python dependency stack, so they are packaged together.
Nothing below is in ::gentoo or ::guru unless stated.

## The engines

- **kokoro 0.9.4** (PyPI, hatchling, pure). Dependencies: huggingface-hub,
  loguru, `misaki[en]>=0.9.4`, numpy, torch, transformers. Python `<3.13`.
- **kittentts 0.1.x**: LocalAI installs it from a GitHub release wheel
  (`KittenML/KittenTTS` release `0.1`, `kittentts-0.1.0-py3-none-any.whl`),
  PyPI has 0.1.3. Dependencies: num2words, spacy, espeakng_loader,
  `misaki[en]>=0.9.4`, onnxruntime, soundfile, numpy, huggingface_hub.
  onnxruntime exists in ::guru only (`sci-libs/onnxruntime`, a large cmake +
  python-r1 build) and is a hard runtime dependency here, unlike
  faster-whisper where it is optional.
- **misaki 0.9.4** (hatchling, pure) is the G2P both use. Base dependencies
  addict and regex. The `en` extra adds espeakng-loader, num2words,
  phonemizer-fork, spacy and spacy-curated-transformers. At run time
  `misaki/en.py` calls `spacy.load(name)` on a pipeline model, which is a
  separate download outside PyPI (spaCy models are GitHub release wheels).
  Python `<3.13`.

## Python version ceiling

misaki and kokoro declare `python_requires <3.13`. On the single-impl
target this means Python 3.12 only for everything above them, including
kitten-tts. Needs a decision on how the overlay handles a 3.12-only
backend when the host's python-single-target is newer.

## espeakng-loader replacement

`espeakng-loader 0.2.4` has no source: wheels bundling a prebuilt
`libespeak-ng.so` 1.52 plus 364 data files. The module is two path
getters, `get_library_path()` and `get_data_path()`, which
`misaki/espeak.py` passes to phonemizer's `EspeakWrapper.set_library()` and
`set_data_path()`.

Plan: patch `misaki/espeak.py` to drop the import and the two `set_*`
calls. phonemizer then finds `libespeak-ng.so` through
`ctypes.util.find_library` (its dlinfo dependency) and the data directory
from the library itself. `app-accessibility/espeak-ng` becomes an RDEPEND
of misaki and phonemizer. kittentts lists `espeakng_loader` as a
requirement of its own: check whether its code imports the loader
directly and patch the same way if so. The tree's espeak-ng version, not
1.52, then drives the phoneme output.

## The spaCy stack

spacy 3.8.18 pins `thinc<8.4`, so thinc 8.3.14, not the current 10.0.0.

Build order, leaves first:

1. cymem 2.0.16, murmurhash 1.0.16 (Cython, no deps).
2. preshed 3.0.15 (Cython; cymem, murmurhash). spacy excludes 3.0.14.
3. catalogue 2.0.10, wasabi 1.1.3 (colorama), spacy-legacy 3.0.12,
   spacy-loggers 1.0.5, dlinfo 2.0.0, language-tags 1.3.2: pure, no deps
   beyond the tree.
4. srsly 2.5.5 (Cython; catalogue), confection 1.3.4 (pure),
   cloudpathlib 0.26.0 (flit), smart-open 9.0.0 (wrapt).
5. blis 1.3.4: see below.
6. thinc 8.3.14 (Cython; blis, murmurhash, cymem, preshed, wasabi, srsly,
   catalogue, confection, numpy, pydantic, packaging).
7. weasel 1.0.1 (confection, packaging, wasabi, srsly, typer, click,
   cloudpathlib, smart-open, httpx, pydantic).
8. spacy 3.8.18 (Cython, 49 modules; everything above plus typer, click,
   tqdm, numpy, requests, pydantic, jinja2, packaging).
9. spacy-curated-transformers 2.1.2 with curated-tokenizers 2.0.1 (Cython)
   and curated-transformers 2.0.1, for misaki's `en` extra.
10. The spaCy pipeline model misaki loads at run time: identify the name
    misaki asks for and package that GitHub release wheel's contents.

Python ceilings along the way: cymem, murmurhash, preshed, srsly, thinc,
spacy, language-tags declare `<3.16`.

## blis: build against sci-libs/blis

The PyPI `blis` package is two Cython modules (`blis.cy`, `blis.py`)
calling BLIS's native typed API (`bli_sgemm_ex`, `bli_dgemv_ex`,
`bli_rntm_init`, `bli_info_get_int_type_size_str`, ...). Its sdist vendors
1585 BLIS C files that `setup.py` compiles from a recorded build log and
links as extra objects.

Plan: patch `ExtensionBuilder.build_extensions` in `setup.py` to skip
`compile_objects` and the `extra_objects` loop, add `/usr/include/blis` to
the include dirs and `blis` to the libraries. RDEPEND `sci-libs/blis:=`.

Integer width matches: cython-blis declares `dim_t`/`inc_t` as int64;
BLIS's configure `-i` defaults to auto, 64-bit on 64-bit targets, and the
portage ebuild keeps that default, so the plain LP64 `libblis` has 64-bit
internal integers. The `index64` flag concerns the BLAS interface, which
this package does not use. To confirm at build: the `_ex` signatures
against the 2.1 headers (the Cython compile checks them).

## phonemizer

- phonemizer 3.4.0 (setuptools, pure, GPL-3): joblib, attrs, dlinfo,
  typing-extensions. Needed by neutts and kitten-tts.
- phonemizer-fork 3.3.2 (hatchling, pure, GPL-3): attrs, dlinfo, joblib,
  segments, typing-extensions. Needed by misaki. segments 2.4.0 pulls csvw
  4.1.1 (isodate, python-dateutil, rfc3986, uritemplate, babel,
  language-tags, rdflib, termcolor, jsonschema).
- Both packages install the same `phonemizer` import name and cannot be
  installed together. Check whether misaki works with upstream phonemizer
  3.4.0 so only one is packaged.

## Already packaged for this stack

num2words (dev-python), lightning-utilities, einx, frozendict, omegaconf
(dev-python); torchao, modelscope, resemble-perth and the rest of the
shared layer under sci-ml.
