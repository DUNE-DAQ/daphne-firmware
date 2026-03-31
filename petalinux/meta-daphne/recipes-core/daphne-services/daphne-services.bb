SUMMARY = "Placeholder package for DAPHNE systemd services"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch

SRC_URI += "file://README.services"

do_install() {
    install -d ${D}${datadir}/daphne-services
    install -m 0644 ${WORKDIR}/README.services ${D}${datadir}/daphne-services/README.services
}

FILES:${PN} += "${datadir}/daphne-services/README.services"
