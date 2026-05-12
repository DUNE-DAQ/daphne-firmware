SUMMARY = "Systemd bring-up units for DAPHNE runtime"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch systemd

SRC_URI += " \
  file://README.services \
  file://firmware.service \
  file://clockchip.service \
  file://endpoint.service \
  file://hermes.service \
  file://daphne.service \
  file://daphne-fw.sh \
  file://daphne-fw-stop.sh \
  file://daphne-clockchip.sh \
  file://daphne-endpoint-init.py \
"

RDEPENDS:${PN} += " \
    bash \
    daphne-overlay \
    daphne-server \
    dfx-mgr \
    fpga-manager-script \
    i2c-tools \
    iproute2-ss \
    python3-core \
    xmutil \
"

SYSTEMD_SERVICE:${PN} = " \
    firmware.service \
    clockchip.service \
    endpoint.service \
    hermes.service \
    daphne.service \
"
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -d ${D}/usr/local/bin
    install -d ${D}${datadir}/daphne-services

    install -m 0644 ${WORKDIR}/README.services \
        ${D}${datadir}/daphne-services/README.services

    for unit in firmware.service clockchip.service endpoint.service hermes.service daphne.service; do
        install -m 0644 ${WORKDIR}/${unit} ${D}${systemd_system_unitdir}/${unit}
    done

    for script in daphne-fw.sh daphne-fw-stop.sh daphne-clockchip.sh daphne-endpoint-init.py; do
        install -m 0755 ${WORKDIR}/${script} ${D}/usr/local/bin/${script}
    done
}

FILES:${PN} += " \
    ${systemd_system_unitdir}/firmware.service \
    ${systemd_system_unitdir}/clockchip.service \
    ${systemd_system_unitdir}/endpoint.service \
    ${systemd_system_unitdir}/hermes.service \
    ${systemd_system_unitdir}/daphne.service \
    /usr/local/bin/daphne-fw.sh \
    /usr/local/bin/daphne-fw-stop.sh \
    /usr/local/bin/daphne-clockchip.sh \
    /usr/local/bin/daphne-endpoint-init.py \
    ${datadir}/daphne-services/README.services \
"
