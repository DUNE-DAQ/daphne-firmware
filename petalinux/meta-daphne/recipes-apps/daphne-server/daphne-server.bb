SUMMARY = "Prebuilt DAPHNE runtime payload"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

DEPENDS += "patchelf-native"

RDEPENDS:${PN} += " \
    i2c-tools \
    zlib \
"

SRC_URI += " \
  file://README.server \
  file://staged/BUILD-METADATA.txt \
  file://staged/daphne-server-runtime-minimal.tgz \
"

PACKAGE_ARCH = "${MACHINE_ARCH}"

FILES_SOLIBSDEV = ""
INSANE_SKIP:${PN} += "dev-so rpaths"

DAPHNE_RUNTIME_LIBDIR = "${libdir}/daphne-server"

do_install() {
    runtime_root="${WORKDIR}"
    lib_src_dir="${runtime_root}/home/petalinux/daphne-server/build-petalinux/_deps/daphne-deps-petalinux2024/prefix/lib"

    install -d ${D}${bindir}
    install -d ${D}${DAPHNE_RUNTIME_LIBDIR}
    install -d ${D}${datadir}/daphne-server

    install -m 0755 "${runtime_root}/bin/hermes_udp_srv" \
        ${D}${bindir}/hermes_udp_srv
    install -m 0755 "${runtime_root}/home/petalinux/daphne-server/build-petalinux/daphneServer" \
        ${D}${bindir}/daphneServer

    for lib in \
        libprotobuf.so \
        libprotobuf.so.30.1.0 \
        libutf8_validity.so \
        libutf8_validity.so.30.1.0 \
        libzmq.so \
        libzmq.so.5 \
        libzmq.so.5.2.4; do
        install -m 0644 "${lib_src_dir}/${lib}" "${D}${DAPHNE_RUNTIME_LIBDIR}/${lib}"
    done

    ${STAGING_BINDIR_NATIVE}/patchelf \
        --set-rpath ${DAPHNE_RUNTIME_LIBDIR} \
        ${D}${bindir}/daphneServer

    install -m 0644 ${WORKDIR}/README.server \
        ${D}${datadir}/daphne-server/README.server
    install -m 0644 ${WORKDIR}/staged/BUILD-METADATA.txt \
        ${D}${datadir}/daphne-server/BUILD-METADATA.txt
}

FILES:${PN} += " \
    ${bindir}/daphneServer \
    ${bindir}/hermes_udp_srv \
    ${libdir}/daphne-server/* \
    ${datadir}/daphne-server/README.server \
    ${datadir}/daphne-server/BUILD-METADATA.txt \
"
