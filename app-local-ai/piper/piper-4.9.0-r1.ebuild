# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-to-speech backend: LocalAI's Go gRPC wrapper around go-piper,
# which builds the piper TTS engine with its phonemizer and the rhasspy fork
# of espeak-ng (vendored deliberately: the fork carries phonemization patches
# and provides the espeak-ng-data this backend ships). fmt/spdlog and
# onnxruntime come from the system.

EAPI=8

inherit go-module local-ai-backend multilib

# Pins. Source of truth: backend/go/piper/Makefile (PIPER_VERSION) at the
# LocalAI release tag; the three below it are go-piper's submodule gitlinks
# at that commit.
GOPIPER_COMMIT="e10ca041a885d4a8f3871d52924b47792d5e5aa0"
PIPER_COMMIT="0987603ebd2a93c3c14289f3914cd9145a7dddb5"
PHONEMIZE_COMMIT="fccd4f335aa68ac0b72600822f34d84363daa2bf"
ESPEAK_COMMIT="8593723f10cfd9befd50de447f14bf0a9d2a14a4"
# piper-phonemize's onnxruntime pin (ONNXRUNTIME_VERSION in its CMakeLists).
ONNX_PV="1.14.1"
# The rhasspy espeak-ng fork FetchContents sonic at configure time
# (cmake/deps.cmake); pinned commit from there.
SONIC_COMMIT="fbf75c3d6d846bad3bb3d456cbc5d07d9fd8c104"

DESCRIPTION="LocalAI text-to-speech backend (piper gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	${LOCAL_AI_GO_SRC_URI}
	https://github.com/mudler/go-piper/archive/${GOPIPER_COMMIT}.tar.gz -> go-piper-${GOPIPER_COMMIT}.tar.gz
	https://github.com/rhasspy/piper/archive/${PIPER_COMMIT}.tar.gz -> piper-${PIPER_COMMIT}.tar.gz
	https://github.com/rhasspy/piper-phonemize/archive/${PHONEMIZE_COMMIT}.tar.gz -> piper-phonemize-${PHONEMIZE_COMMIT}.tar.gz
	https://github.com/rhasspy/espeak-ng/archive/${ESPEAK_COMMIT}.tar.gz -> rhasspy-espeak-ng-${ESPEAK_COMMIT}.tar.gz
	https://github.com/waywardgeek/sonic/archive/${SONIC_COMMIT}.tar.gz -> sonic-${SONIC_COMMIT}.tar.gz
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/piper"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	sci-ml/local-ai
	dev-libs/libfmt:=
	dev-libs/spdlog:=
	|| (
		sci-libs/onnxruntime
		sci-libs/onnxruntime-bin
	)
"
DEPEND="${RDEPEND}"

GOPIPER="${S}/sources/go-piper"

src_unpack() {
	local-ai-backend_go_unpack

	# sonic stays in WORKDIR: src_prepare points espeak's FetchContent
	# at it there.
	unpack "sonic-${SONIC_COMMIT}.tar.gz"

	# go-piper with its submodule checkouts, as upstream's clone targets
	# would lay them out; the Makefile's network-using targets are then
	# skipped because their directories already exist.
	local subs=(
		"piper-${PIPER_COMMIT}.tar.gz" "piper-${PIPER_COMMIT}" piper
		"piper-phonemize-${PHONEMIZE_COMMIT}.tar.gz" "piper-phonemize-${PHONEMIZE_COMMIT}" piper-phonemize
		"rhasspy-espeak-ng-${ESPEAK_COMMIT}.tar.gz" "espeak-ng-${ESPEAK_COMMIT}" espeak
	)
	local-ai-backend_engine_unpack "go-piper-${GOPIPER_COMMIT}.tar.gz" go-piper "${subs[@]}"
}

src_prepare() {
	default

	# The phonemize cmake invocation in go-piper's Makefile takes no
	# argument passthrough; inject the onnxruntime location so its
	# download-if-missing logic never triggers.
	# go-piper's Makefile assigns its own CFLAGS/CXXFLAGS/LDFLAGS (include
	# paths, -lucd, ...). Because Portage exports those names, make
	# re-exports the reassigned values to the espeak/phonemize/piper cmake
	# children — whose compiler sanity checks then link -lucd before it is
	# built. Rename go-piper's private copies so the children inherit the
	# real Portage flags and the recipes keep their own values.
	einfo "Renaming go-piper's private *FLAGS so Portage flags reach the cmake sub-builds"
	sed -i 's/\bCFLAGS\b/GP_CFLAGS/g; s/\bCXXFLAGS\b/GP_CXXFLAGS/g; s/\bLDFLAGS\b/GP_LDFLAGS/g' "${GOPIPER}/Makefile" || die
	grep -q 'GP_LDFLAGS' "${GOPIPER}/Makefile" || die "flags rename did not apply"

	einfo "Pointing espeak's sonic FetchContent at the unpacked source"
	sed -i "s|cd espeak/ei && cmake ..|cd espeak/ei \&\& cmake .. -DFETCHCONTENT_SOURCE_DIR_SONIC-GIT=${WORKDIR}/sonic-${SONIC_COMMIT}|" "${GOPIPER}/Makefile" || die
	grep -q 'FETCHCONTENT_SOURCE_DIR_SONIC-GIT' "${GOPIPER}/Makefile" || die "sonic redirect did not apply"

	einfo "Injecting ONNXRUNTIME_DIR into go-piper's phonemize cmake invocation"
	sed -i "s|cd piper-phonemize/pi && cmake .. --debug-output|cd piper-phonemize/pi \&\& cmake .. --debug-output -DONNXRUNTIME_DIR=${T}/onnx-prefix|" "${GOPIPER}/Makefile" || die
	grep -q "onnx-prefix" "${GOPIPER}/Makefile" || die "onnxruntime injection did not apply"
}

# Provide ${T}/onnx-prefix with include/ and lib/ as piper-phonemize expects.
setup_onnx_prefix() {
	# Real directories with only the onnxruntime pieces: phonemize's
	# install() copies both include/ and lib/ of this prefix into its
	# own tree, so symlinking /usr/include or the system libdir here
	# would sweep system-wide content into the package staging.
	mkdir -p "${T}/onnx-prefix/include" "${T}/onnx-prefix/lib" || die
	cp -rL "${ESYSROOT}/usr/include/onnxruntime/." "${T}/onnx-prefix/include/" || die
	cp -a "${ESYSROOT}/usr/$(get_libdir)"/libonnxruntime.so* "${T}/onnx-prefix/lib/" || die
}

src_compile() {
	setup_onnx_prefix

	# FMT_DIR/SPDLOG_DIR defined => piper's ExternalProject downloads are
	# skipped and the system libraries are used. CMAKE_ARGS reaches the
	# piper cmake line through go-piper's Makefile.
	local -x CMAKE_ARGS="-DFMT_DIR=${ESYSROOT}/usr -DSPDLOG_DIR=${ESYSROOT}/usr"
	emake -C "${S}" piper
}

src_install() {
	local dest="${LOCAL_AI_BACKENDS_DIR#${EPREFIX}}/piper"

	local-ai-backend_install piper "${S}/piper"

	insinto "${dest}"
	doins -r "${S}/espeak-ng-data"

	exeinto "${dest}/lib"
	# phonemize's install copies the onnxruntime lib into pi/lib; the
	# system copy must not be bundled (RDEPEND provides it).
	rm -f "${GOPIPER}"/piper-phonemize/pi/lib/libonnxruntime.so* || die
	doexe "${GOPIPER}"/piper-phonemize/pi/lib/lib*.so*
	doexe "${GOPIPER}"/espeak/ei/lib/lib*.so* 2>/dev/null || true
}
