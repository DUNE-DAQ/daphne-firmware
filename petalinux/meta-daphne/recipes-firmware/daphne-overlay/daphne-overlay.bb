SUMMARY = "Placeholder package for DAPHNE firmware overlay assets"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch

SRC_URI += " \
  file://README.overlay \
  file://staged/BUILD-METADATA.txt \
"

python __anonymous() {
    import os
    staged_dir = d.expand("${THISDIR}/files/staged")
    staged_files = (
        "daphne-overlay.dtbo",
        "daphne-overlay.bin",
        "shell.json",
        "SHA256SUMS",
    )
    for name in staged_files:
        path = os.path.join(staged_dir, name)
        if os.path.exists(path):
            d.appendVar("SRC_URI", f" file://staged/{name}")
}

do_install() {
    install -d ${D}${datadir}/daphne-firmware
    install -m 0644 ${WORKDIR}/README.overlay ${D}${datadir}/daphne-firmware/README.overlay
    install -m 0644 ${WORKDIR}/staged/BUILD-METADATA.txt ${D}${datadir}/daphne-firmware/BUILD-METADATA.txt

    for f in daphne-overlay.dtbo daphne-overlay.bin shell.json SHA256SUMS; do
        if [ -f "${WORKDIR}/staged/$f" ]; then
            install -m 0644 "${WORKDIR}/staged/$f" "${D}${datadir}/daphne-firmware/$f"
        fi
    done
}

FILES:${PN} += "${datadir}/daphne-firmware/*"
