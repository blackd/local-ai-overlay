# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# LocalAI text-to-speech backend: LocalAI's Go gRPC wrapper around go-piper,
# which builds the piper TTS engine with its phonemizer and the rhasspy fork
# of espeak-ng (vendored deliberately: the fork carries phonemization patches
# and provides the espeak-ng-data this backend ships). fmt/spdlog come from
# the system; onnxruntime comes from the system by default (USE flag below).

EAPI=8

inherit go-module localai-backend multilib

# Pins. Source of truth: backend/go/piper/Makefile (PIPER_VERSION) at the
# LocalAI release tag; the three below it are go-piper's submodule gitlinks
# at that commit.
GOPIPER_COMMIT="e10ca041a885d4a8f3871d52924b47792d5e5aa0"
PIPER_COMMIT="0987603ebd2a93c3c14289f3914cd9145a7dddb5"
PHONEMIZE_COMMIT="fccd4f335aa68ac0b72600822f34d84363daa2bf"
ESPEAK_COMMIT="8593723f10cfd9befd50de447f14bf0a9d2a14a4"
# piper-phonemize's onnxruntime pin (ONNXRUNTIME_VERSION in its CMakeLists).
ONNX_PV="1.14.1"

DESCRIPTION="LocalAI text-to-speech backend (piper gRPC server)"
HOMEPAGE="https://localai.io https://github.com/mudler/LocalAI"
SRC_URI="
	https://github.com/mudler/LocalAI/archive/refs/tags/v${PV}.tar.gz -> local-ai-${PV}.tar.gz
	${DISTFILES_BASE}/local-ai-${PV}-deps.tar.xz
	https://github.com/mudler/go-piper/archive/${GOPIPER_COMMIT}.tar.gz -> go-piper-${GOPIPER_COMMIT}.tar.gz
	https://github.com/rhasspy/piper/archive/${PIPER_COMMIT}.tar.gz -> piper-${PIPER_COMMIT}.tar.gz
	https://github.com/rhasspy/piper-phonemize/archive/${PHONEMIZE_COMMIT}.tar.gz -> piper-phonemize-${PHONEMIZE_COMMIT}.tar.gz
	https://github.com/rhasspy/espeak-ng/archive/${ESPEAK_COMMIT}.tar.gz -> rhasspy-espeak-ng-${ESPEAK_COMMIT}.tar.gz
	!system-onnxruntime? ( https://git.ipnmod.org/packages/local-ai-overlay/releases/download/thirdparty/onnxruntime-${ONNX_PV}-src-bundle.tar.xz )
"
S="${WORKDIR}/LocalAI-${PV}/backend/go/piper"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+system-onnxruntime"

RDEPEND="
	sci-ml/local-ai
	dev-libs/libfmt:=
	dev-libs/spdlog:=
	system-onnxruntime? ( sci-libs/onnxruntime:= )
"
DEPEND="${RDEPEND}"
BDEPEND=">=dev-lang/go-1.26"

GOPIPER="${S}/sources/go-piper"

src_unpack() {
	unpack "local-ai-${PV}.tar.gz" "local-ai-${PV}-deps.tar.xz"
	if ! use system-onnxruntime; then
		unpack "onnxruntime-${ONNX_PV}-src-bundle.tar.xz"
	fi

	# Assemble the layout upstream's clone targets would produce; the
	# Makefile's network-using targets are then skipped because their
	# directories already exist.
	cd "${WORKDIR}" || die
	unpack "go-piper-${GOPIPER_COMMIT}.tar.gz"
	unpack "piper-${PIPER_COMMIT}.tar.gz"
	unpack "piper-phonemize-${PHONEMIZE_COMMIT}.tar.gz"
	unpack "rhasspy-espeak-ng-${ESPEAK_COMMIT}.tar.gz"
	mkdir -p "${S}/sources" || die
	mv "go-piper-${GOPIPER_COMMIT}" "${GOPIPER}" || die
	rmdir "${GOPIPER}/piper" "${GOPIPER}/piper-phonemize" "${GOPIPER}/espeak" 2>/dev/null
	mv "piper-${PIPER_COMMIT}" "${GOPIPER}/piper" || die
	mv "piper-phonemize-${PHONEMIZE_COMMIT}" "${GOPIPER}/piper-phonemize" || die
	mv "espeak-ng-${ESPEAK_COMMIT}" "${GOPIPER}/espeak" || die
}

src_prepare() {
	default

	# The phonemize cmake invocation in go-piper's Makefile takes no
	# argument passthrough; inject the onnxruntime location so its
	# download-if-missing logic never triggers.
	sed -i "s|cd piper-phonemize/pi && cmake .. --debug-output|cd piper-phonemize/pi \&\& cmake .. --debug-output -DONNXRUNTIME_DIR=${T}/onnx-prefix|" "${GOPIPER}/Makefile" || die
	grep -q "onnx-prefix" "${GOPIPER}/Makefile" || die "onnxruntime injection did not apply"
}

# Provide ${T}/onnx-prefix with include/ and lib/ as piper-phonemize expects.
setup_onnx_prefix() {
	mkdir -p "${T}/onnx-prefix" || die
	if use system-onnxruntime; then
		# Gentoo nests the headers under include/onnxruntime/ while
		# phonemize expects them directly under <dir>/include.
		ln -s "${ESYSROOT}/usr/include/onnxruntime" "${T}/onnx-prefix/include" || die
		ln -s "${ESYSROOT}/usr/$(get_libdir)" "${T}/onnx-prefix/lib" || die
	else
		local b="${WORKDIR}/onnxruntime-${ONNX_PV}"
		local bd="${WORKDIR}/onnxruntime_build"
		# 1.14.x third-party deps are bundled git submodules in the src
		# bundle, so this configures offline.
		cmake -S "${b}/cmake" -B "${bd}" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${T}/onnx-prefix" -Donnxruntime_BUILD_SHARED_LIB=ON -Donnxruntime_BUILD_UNIT_TESTS=OFF || die
		cmake --build "${bd}" || die
		cmake --install "${bd}" || die
	fi
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
	local dest="${LOCALAI_BACKENDS_DIR#${EPREFIX}}/piper"

	exeinto "${dest}"
	doexe "${S}/piper"
	doexe "${FILESDIR}"/run.sh

	insinto "${dest}"
	doins "${FILESDIR}"/metadata.json
	doins -r "${S}/espeak-ng-data"

	exeinto "${dest}/lib"
	doexe "${GOPIPER}"/piper-phonemize/pi/lib/lib*.so*
	doexe "${GOPIPER}"/espeak/ei/lib/lib*.so* 2>/dev/null || true
	if ! use system-onnxruntime; then
		doexe "${T}"/onnx-prefix/lib/libonnxruntime.so*
	fi

	dosym -r "${dest}" "${LOCALAI_RUNTIME_BACKENDS_DIR}/piper"
}
