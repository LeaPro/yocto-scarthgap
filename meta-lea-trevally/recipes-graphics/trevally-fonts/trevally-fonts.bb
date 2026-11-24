SUMMARY = "Fallback fonts for application-server's UI"
DESCRIPTION = "The fonts application-server draws characters from that its Satoshi bitmap fonts don't have \
(see Trevally application-server ui/font_fallback.h): DejaVu Sans (punctuation, Latin, Greek, Cyrillic, \
Hebrew, Arabic) and Source Han Sans CN Medium (Chinese). Only the two files it uses, in \
/usr/share/fonts/trevally, without fontconfig."
HOMEPAGE = "https://github.com/adobe-fonts/source-han-sans"
LICENSE = "BitstreamVera & OFL-1.1"
LIC_FILES_CHKSUM = "file://dejavu-fonts-ttf-${DEJAVU_PV}/LICENSE;md5=449b2c30bfe5fa897fe87b8b70b16cfa \
                    file://LICENSE.txt;md5=28010d6596196c21d55c40589bac441f"

DEJAVU_PV = "2.37"
SRC_URI = " \
    ${SOURCEFORGE_MIRROR}/dejavu/dejavu-fonts-ttf-${DEJAVU_PV}.tar.bz2;name=dejavu;subdir=${BP} \
    https://github.com/adobe-fonts/source-han-sans/releases/download/2.004R/SourceHanSansCN.zip;name=han;subdir=${BP} \
"
SRC_URI[dejavu.sha256sum] = "fa9ca4d13871dd122f61258a80d01751d603b4d3ee14095d65453b4e846e17d7"
SRC_URI[han.sha256sum] = "6841fc13f1c0d255cfeb33d2a2c68d24bbebd94ae2c070347a2b2b200a1db4d6"

S = "${WORKDIR}/${BP}"

inherit allarch

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${datadir}/fonts/trevally
    install -m 0644 ${S}/dejavu-fonts-ttf-${DEJAVU_PV}/ttf/DejaVuSans.ttf ${D}${datadir}/fonts/trevally/
    install -m 0644 ${S}/SubsetOTF/CN/SourceHanSansCN-Medium.otf ${D}${datadir}/fonts/trevally/
}

FILES:${PN} = "${datadir}/fonts/trevally"
