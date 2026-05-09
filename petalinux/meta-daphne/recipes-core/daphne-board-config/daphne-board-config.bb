SUMMARY = "Board inventory and per-board runtime configuration for DAPHNE"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch systemd

SRC_URI += " \
  file://ff0b_board_inventory.csv \
  file://daphne-board-config-apply.py \
  file://daphne-board-identity.sh \
  file://daphne-board-identity.service \
  file://fw_env.config \
"

RDEPENDS:${PN} += "python3-core"

PACKAGE_ARCH = "${MACHINE_ARCH}"

# Leave empty to install only the shared inventory and helper. Set this in the
# image config to stamp a specific board identity into /etc at build time.
DAPHNE_BOARD_ID ?= ""

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "daphne-board-identity.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${datadir}/daphne-board-config
    install -d ${D}${bindir}
    install -d ${D}${prefix}/local/bin
    install -d ${D}${systemd_system_unitdir}

    install -m 0644 ${WORKDIR}/ff0b_board_inventory.csv \
        ${D}${datadir}/daphne-board-config/ff0b_board_inventory.csv
    install -m 0755 ${WORKDIR}/daphne-board-config-apply.py \
        ${D}${bindir}/daphne-board-config-apply
    install -m 0755 ${WORKDIR}/daphne-board-identity.sh \
        ${D}${prefix}/local/bin/daphne-board-identity.sh
    install -m 0644 ${WORKDIR}/daphne-board-identity.service \
        ${D}${systemd_system_unitdir}/daphne-board-identity.service
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/fw_env.config \
        ${D}${sysconfdir}/fw_env.config

    if [ -n "${DAPHNE_BOARD_ID}" ]; then
        ${PYTHON} ${WORKDIR}/daphne-board-config-apply.py \
            --inventory ${WORKDIR}/ff0b_board_inventory.csv \
            --board-id ${DAPHNE_BOARD_ID} \
            --root ${D}
    fi
}

FILES:${PN} += " \
    ${bindir}/daphne-board-config-apply \
    ${datadir}/daphne-board-config/ff0b_board_inventory.csv \
    ${prefix}/local/bin/daphne-board-identity.sh \
    ${systemd_system_unitdir}/daphne-board-identity.service \
    /etc/default/firmware \
    /etc/daphne-board.env \
    /etc/daphne-uboot.env \
    /etc/fw_env.config \
    /etc/systemd/network/10-ff0b.link \
    /etc/systemd/network/11-ff0c.link \
    /etc/systemd/network/20-ff0b.network \
    /etc/systemd/network/21-ff0c.network \
"

CONFFILES:${PN} += " \
    /etc/default/firmware \
    /etc/daphne-board.env \
    /etc/daphne-uboot.env \
    /etc/fw_env.config \
    /etc/systemd/network/10-ff0b.link \
    /etc/systemd/network/11-ff0c.link \
    /etc/systemd/network/20-ff0b.network \
    /etc/systemd/network/21-ff0c.network \
"
