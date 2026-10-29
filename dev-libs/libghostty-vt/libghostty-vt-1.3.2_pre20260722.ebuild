# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# libghostty-vt, Ghostty's terminal emulation core as a C library, at
# the exact Ghostty commit dev-util/opencode-pty pins: its Rust
# bindings are generated from this revision's include/ghostty headers
# and its build refuses any other. The revision is 1443 commits past
# the 1.3.1 release x11-terms/ghostty packages and the lib-vt headers
# differ substantially, so this is a snapshot package that moves with
# opencode-pty's pin, not with Ghostty releases.
#
# Zig insists on every dependency declared in the build.zig.zon files
# being present, used by the lib-vt target or not, so ZBS_DEPENDENCIES
# carries the whole set (the same way x11-terms/ghostty does), including
# the three git references resolved to GitHub archives of the pinned
# commits (arocc for translate_c, zigimg and libvaxis for vaxis and zf).
# The C dependencies the target uses are built from these sources and
# combined into the static archive as upstream ships it; nothing is
# downloaded at build time (zig runs in --system mode).

EAPI=8

ZIG_SLOT="0.16"
# Build system dependencies, "<package hash>.<ext>" -> URL, as the zig
# eclass expects them. Collected from build.zig.zon and pkg/*/build.zig.zon
# of the pinned revision plus the zon files of the Zig packages among them.
declare -g -r -A ZBS_DEPENDENCIES=(
	# Zig packages (root build.zig.zon)
	[translate_c-0.0.0-Q_BUWj8_BwCr4na219OimiKKj4IVSq0aKtMXCQmIk4AB.tar.gz]='https://deps.files.ghostty.org/translate_c-a916baf225a3cfc93a982225462db612604ae290.tar.gz'
	[libxev-0.0.0-86vtcwIRFADbH4hk-EjROXxlrKIRPQdA41XiTSytYO-F.tar.gz]='https://deps.files.ghostty.org/libxev-9ce8e8e6ff89e583258a7f8e7adeeeaeae8611bf.tar.gz'
	[vaxis-0.6.0-BWNV_CrbCQCscGpzsAlR402rYQ_tV3aAl081c2iRRkka.tar.gz]='https://deps.files.ghostty.org/vaxis-1dbbe575dff4586fe51e3217aa5c3fecdcbb6089.tar.gz'
	[z2d-0.11.0-j5P_HtLzDwBGyQt49DrT0v4BuVqI_SRs6CXsuj7eBVhR.tar.gz]='https://deps.files.ghostty.org/z2d-0.11.0-j5P_HtLzDwBGyQt49DrT0v4BuVqI_SRs6CXsuj7eBVhR.tar.gz'
	[zig_objc-0.0.0-Ir_Sp9gsAQCPAJc0oF5xoWePHWP6Y6tCphDeyNUThJoi.tar.gz]='https://deps.files.ghostty.org/zig_objc-c8de82ff80281215ad92900866dab7103a8efa8b.tar.gz'
	[zig_js-0.0.0-rjCAV7-GAADvMTBL7lPMuvDk7xgS9PCMIZWiOUXLZSlj.tar.gz]='https://deps.files.ghostty.org/zig_js-3c23860e47fdcdc5af805efb7fd0bdac5fd3e9bc.tar.gz'
	[uucode-0.2.0-ZZjBPlK5VADj7fdoq7G8LIHzD5o6FSkcBXXrRWr4jnrA.tar.gz]='https://deps.files.ghostty.org/uucode-2826a37a4562284fdacd8fa029d49509cc9bffcd.tar.gz'
	[wayland-0.6.0-lQa1kqz8AQADQmdNJsNhLoNHcnEGEUjrOaPV-dtEnEmX.tar.gz]='https://deps.files.ghostty.org/wayland-0.6.0-lQa1kqz8AQADQmdNJsNhLoNHcnEGEUjrOaPV-dtEnEmX.tar.gz'
	[zf-0.11.0-OIRy8X-RAAAwaRXHMYpj2uvBnuGTZWEE_3V7acqHQNtW.tar.gz]='https://deps.files.ghostty.org/zf-c35c421f84895193246db06c40683c1a30e616ef.tar.gz'
	[gobject-0.3.1-Skun7E1KnwBGMX5nslHYG1yWHaSevywxQO8oM7tTOgIp.tar.zst]='https://deps.files.ghostty.org/gobject-2026-04-23-26-1.tar.zst'
	# Transitive Zig packages: translate_c -> arocc, vaxis -> zigimg, zf -> libvaxis
	[aro-0.0.0-JSD1Qk8rOQDnuVcD4jAwMpHitA6pADRKzQ7M7hKRwxvD.tar.gz]='https://github.com/vancluever/arocc/archive/ecbc5c799574e0da2758a961b12efa586007f03c.tar.gz'
	[zigimg-0.1.0-8_eo2oyaFwBZwJpmqPkCfVXWBrHcqbYwmrp1I6bTD3lI.tar.gz]='https://github.com/zigimg/zigimg/archive/d695acd97c02e57bb151e8f659d1280f5cd6ca70.tar.gz'
	[vaxis-0.6.0-BWNV_MjFCQCs9UDHiRkrgw_ayeiPkzOe4xVbaAqXkUWW.tar.gz]='https://github.com/rockorager/libvaxis/archive/c1e1f23be38951c425cdf31af455ba23ef178940.tar.gz'
	# Wayland protocol sources, fonts, themes (root build.zig.zon)
	[N-V-__8AAKrHGAAs2shYq8UkE6bGcR1QJtLTyOE_lcosMn6t.tar.gz]='https://deps.files.ghostty.org/wayland-9cb3d7aa9dc995ffafdbdef7ab86a949d0fb0e7d.tar.gz'
	[N-V-__8AAFdWDwA0ktbNUi9pFBHCRN4weXIgIfCrVjfGxqgA.tar.gz]='https://deps.files.ghostty.org/N-V-__8AAFdWDwA0ktbNUi9pFBHCRN4weXIgIfCrVjfGxqgA.tar.gz'
	[N-V-__8AAKYZBAB-CFHBKs3u4JkeiT4BMvyHu3Y5aaWF3Bbs.tar.gz]='https://deps.files.ghostty.org/plasma_wayland_protocols-12207e0851c12acdeee0991e893e0132fc87bb763969a585dc16ecca33e88334c566.tar.gz'
	[N-V-__8AAIC5lwAVPJJzxnCAahSvZTIlG-HhtOvnM1uh-66x.tar.gz]='https://deps.files.ghostty.org/JetBrainsMono-2.304.tar.gz'
	[N-V-__8AAMVLTABmYkLqhZPLXnMl-KyN38R8UVYqGrxqO26s.tar.gz]='https://deps.files.ghostty.org/NerdFontsSymbolsOnly-3.4.0.tar.gz'
	[N-V-__8AALZGBAAS5NLVH-c8eC-6VtCdcH-9nUvVfUSkWS__.tar.gz]='https://deps.files.ghostty.org/ghostty-themes-release-20260713-155359-c3968b3.tgz'
	# C library sources (pkg/*/build.zig.zon)
	[N-V-__8AALw2uwF_03u4JRkZwRLc3Y9hakkYV7NKRR9-RIZJ.tar.gz]='https://deps.files.ghostty.org/breakpad-b99f444ba5f6b98cac261cbb391d8766b34a5918.tar.gz'
	[N-V-__8AAEbOfQBnvcFcCX2W5z7tDaN8vaNZGamEQtNOe0UI.tar.gz]='https://deps.files.ghostty.org/N-V-__8AAEbOfQBnvcFcCX2W5z7tDaN8vaNZGamEQtNOe0UI.tar.gz'
	[N-V-__8AANT61wB--nJ95Gj_ctmzAtcjloZ__hRqNw5lC1Kr.tar.gz]='https://deps.files.ghostty.org/DearBindings_v0.17_ImGui_v1.92.5-docking.tar.gz'
	[N-V-__8AAIrfdwARSa-zMmxWwFuwpXf1T3asIN7s5jqi9c1v.tar.gz]='https://deps.files.ghostty.org/fontconfig-2.14.2.tar.gz'
	[N-V-__8AAKLKpwC4H27Ps_0iL3bPkQb-z6ZVSrB-x_3EEkub.tar.gz]='https://deps.files.ghostty.org/freetype-1220b81f6ecfb3fd222f76cf9106fecfa6554ab07ec7fdc4124b9bb063ae2adf969d.tar.gz'
	[N-V-__8AABzkUgISeKGgXAzgtutgJsZc0-kkeqBBscJgMkvy.tar.gz]='https://deps.files.ghostty.org/glslang-12201278a1a05c0ce0b6eb6026c65cd3e9247aa041b1c260324bf29cee559dd23ba1.tar.gz'
	[N-V-__8AALiNBAA-_0gprYr92CjrMj1I5bqNu0TSJOnjFNSr.tar.gz]='https://deps.files.ghostty.org/gtk4-layer-shell-1.1.0.tar.gz'
	[N-V-__8AAKw-DAAaV8bOAAGqA0-oD7o-HNIlPFYKRXSPT03S.tar.gz]='https://deps.files.ghostty.org/wayland-protocols-258d8f88f2c8c25a830c6316f87d23ce1a0f12d9.tar.gz'
	[N-V-__8AAG02ugUcWec-Ndp-i7JTsJ0dgF8nnJRUInkGLG7G.tar.xz]='https://deps.files.ghostty.org/harfbuzz-11.0.0.tar.xz'
	[N-V-__8AAGmZhABbsPJLfbqrh6JTHsXhY6qCaLAQyx25e0XE.tar.gz]='https://deps.files.ghostty.org/highway-66486a10623fa0d72fe91260f96c892e41aceb06.tar.gz'
	[N-V-__8AADcZkgn4cMhTUpIz6mShCKyqqB-NBtf_S2bHaTC-.tar.gz]='https://deps.files.ghostty.org/gettext-0.24.tar.gz'
	[N-V-__8AAJrvXQCqAT8Mg9o_tk6m0yf5Fz-gCNEOKLyTSerD.tar.gz]='https://deps.files.ghostty.org/libpng-1220aa013f0c83da3fb64ea6d327f9173fa008d10e28bc9349eac3463457723b1c66.tar.gz'
	[N-V-__8AAG3RoQEyRC2Vw7Qoro5SYBf62IHn3HjqtNVY6aWK.tar.gz]='https://deps.files.ghostty.org/libxml2-2.11.5.tar.gz'
	[N-V-__8AAHjwMQDBXnLq3Q2QhaivE0kE2aD138vtX2Bq1g7c.tar.gz]='https://deps.files.ghostty.org/oniguruma-1220c15e72eadd0d9085a8af134904d9a0f5dfcbed5f606ad60edc60ebeccd9706bb.tar.gz'
	[N-V-__8AAPlZGwBEa-gxrcypGBZ2R8Bse4JYSfo_ul8i2jlG.tar.gz]='https://deps.files.ghostty.org/sentry-1220446be831adcca918167647c06c7b825849fa3fba5f22da394667974537a9c77e.tar.gz'
	[N-V-__8AANb6pwD7O1WG6L5nvD_rNMvnSc9Cpg1ijSlTYywv.tar.gz]='https://deps.files.ghostty.org/spirv_cross-1220fb3b5586e8be67bc3feb34cbe749cf42a60d628d2953632c2f8141302748c8da.tar.gz'
	[N-V-__8AADYiAAB_80AWnH1AxXC0tql9thT-R-DYO1gBqTLc.tar.gz]='https://deps.files.ghostty.org/pixels-12207ff340169c7d40c570b4b6a97db614fe47e0d83b5801a932dcd44917424c8806.tar.gz'
	[N-V-__8AAAzZywE3s51XfsLbP9eyEw57ae9swYB9aGB6fCMs.tar.gz]='https://deps.files.ghostty.org/wuffs-122037b39d577ec2db3fd7b2130e7b69ef6cc1807d68607a7c232c958315d381b5cd.tar.gz'
	[N-V-__8AAB0eQwD-0MdOEBmz7intriBReIsIDNlukNVoNu6o.tar.gz]='https://deps.files.ghostty.org/zlib-1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb.tar.gz'
)

inherit zig

GHOSTTY_COMMIT="ab0b9da9e88fcb4b0533a1854e84628f663930af"
# Ghostty's own version string at this commit; the build wants one
# because it has no git checkout to read it from.
GHOSTTY_VERSION="1.3.2-dev"

DESCRIPTION="Ghostty's terminal emulation core as a C library (libghostty-vt)"
HOMEPAGE="https://ghostty.org/ https://github.com/ghostty-org/ghostty"
SRC_URI="
	https://github.com/ghostty-org/ghostty/archive/${GHOSTTY_COMMIT}.tar.gz -> ghostty-${GHOSTTY_COMMIT}.tar.gz
	${ZBS_DEPENDENCIES_SRC_URI}
"
S="${WORKDIR}/ghostty-${GHOSTTY_COMMIT}"

# Ghostty is MIT; the rest covers the dependency sources combined into
# the static archive, the same set x11-terms/ghostty declares.
LICENSE="MIT Apache-2.0 BSD BSD-2 BSD-4 Boost-1.0 MPL-2.0 Unicode-3.0"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND="
	|| (
		>=dev-lang/zig-bin-0.16.0:${ZIG_SLOT}
		>=dev-lang/zig-0.16.0:${ZIG_SLOT}
	)
"

src_configure() {
	local my_zbs_args=(
		--release=fast
		-Demit-lib-vt=true
		-Dapp-runtime=none
		-Demit-xcframework=false
		-Dversion-string="${GHOSTTY_VERSION}"
		-Dstrip=false
	)
	zig_src_configure
}
