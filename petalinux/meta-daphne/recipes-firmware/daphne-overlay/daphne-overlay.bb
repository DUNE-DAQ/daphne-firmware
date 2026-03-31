SUMMARY = "Placeholder package for DAPHNE firmware overlay assets"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch

SRC_URI += "file://README.overlay"

do_install() {
    install -d ${D}${datadir}/daphne-firmware
    install -m 0644 ${WORKDIR}/README.overlay ${D}${datadir}/daphne-firmware/README.overlay
}

FILES:${PN} += "${datadir}/daphne-firmware/README.overlay"
