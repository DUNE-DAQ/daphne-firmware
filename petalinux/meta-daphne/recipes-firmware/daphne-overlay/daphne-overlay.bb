SUMMARY = "DAPHNE firmware overlay assets"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch

SRC_URI += " \
  file://README.overlay \
  file://staged/BUILD-METADATA.txt \
  file://staged/daphne-overlay.dtbo \
  file://staged/daphne-overlay.bin \
  file://staged/shell.json \
  file://staged/SHA256SUMS \
"

DAPHNE_OVERLAY_APP ?= "daphne_selftrigger_ol_a389fcd"
DAPHNE_LEGACY_OVERLAY_ALIASES ?= "MEZ_SELF_TRIG_V15_OL_UPGRADED MEZ_ALT_FW_TIMING_OL_UPGRADED"
DAPHNE_OVERLAY_FIRMWARE_NAME ?= "daphne_selftrigger_7353a17.bit.bin"

do_install() {
    app_dir="${D}/lib/firmware/xilinx/${DAPHNE_OVERLAY_APP}"

    install -d "${app_dir}"
    install -d ${D}${datadir}/daphne-firmware

    install -m 0644 ${WORKDIR}/README.overlay \
        ${D}${datadir}/daphne-firmware/README.overlay
    install -m 0644 ${WORKDIR}/staged/BUILD-METADATA.txt \
        "${app_dir}/BUILD-METADATA.txt"
    install -m 0644 ${WORKDIR}/staged/SHA256SUMS \
        "${app_dir}/SHA256SUMS"
    install -m 0644 ${WORKDIR}/staged/shell.json \
        "${app_dir}/shell.json"
    install -m 0644 ${WORKDIR}/staged/daphne-overlay.bin \
        "${app_dir}/daphne-overlay.bin"
    install -m 0644 ${WORKDIR}/staged/daphne-overlay.dtbo \
        "${app_dir}/daphne-overlay.dtbo"

    ln -snf daphne-overlay.bin "${app_dir}/${DAPHNE_OVERLAY_APP}.bin"
    ln -snf daphne-overlay.dtbo "${app_dir}/${DAPHNE_OVERLAY_APP}.dtbo"
    ln -snf "xilinx/${DAPHNE_OVERLAY_APP}/${DAPHNE_OVERLAY_APP}.bin" \
        "${D}/lib/firmware/${DAPHNE_OVERLAY_FIRMWARE_NAME}"

    for alias in ${DAPHNE_LEGACY_OVERLAY_ALIASES}; do
        ln -snf ${DAPHNE_OVERLAY_APP} "${D}/lib/firmware/xilinx/${alias}"
    done
}

FILES:${PN} += " \
    ${datadir}/daphne-firmware/README.overlay \
    /lib/firmware/${DAPHNE_OVERLAY_FIRMWARE_NAME} \
    /lib/firmware/xilinx/${DAPHNE_OVERLAY_APP} \
    /lib/firmware/xilinx/${DAPHNE_OVERLAY_APP}/* \
    /lib/firmware/xilinx/MEZ_SELF_TRIG_V15_OL_UPGRADED \
    /lib/firmware/xilinx/MEZ_ALT_FW_TIMING_OL_UPGRADED \
"
