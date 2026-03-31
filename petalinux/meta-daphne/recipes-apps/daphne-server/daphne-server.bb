SUMMARY = "Placeholder package for daphne-server deployment"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch

SRC_URI += "file://README.server"

do_install() {
    install -d ${D}${datadir}/daphne-server
    install -m 0644 ${WORKDIR}/README.server ${D}${datadir}/daphne-server/README.server
}

FILES:${PN} += "${datadir}/daphne-server/README.server"
