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
  file://staged/SHA256SUMS \
  file://staged/daphne-server-runtime-minimal.tgz;unpack=0 \
"

PACKAGE_ARCH = "${MACHINE_ARCH}"

FILES_SOLIBSDEV = ""
INSANE_SKIP:${PN} += "dev-so rpaths"

DAPHNE_RUNTIME_LIBDIR = "${libdir}/daphne-server"

do_install() {
    expected_sha="$(awk '$2 == "daphne-server-runtime-minimal.tgz" {print $1}' ${WORKDIR}/staged/SHA256SUMS)"
    actual_sha="$(sha256sum ${WORKDIR}/staged/daphne-server-runtime-minimal.tgz | awk '{print $1}')"
    if [ -z "${expected_sha}" ] || [ "${actual_sha}" != "${expected_sha}" ]; then
        bbfatal "DAPHNE runtime bundle checksum verification failed"
    fi

    runtime_root="${WORKDIR}/runtime-root"
    rm -rf "${runtime_root}"
    install -d "${runtime_root}"
    tar -xzf "${WORKDIR}/staged/daphne-server-runtime-minimal.tgz" \
        -C "${runtime_root}"
    deps_root="${runtime_root}/home/petalinux/daphne-server/build-petalinux/_deps"
    lib_src_dir="$(find "${deps_root}" -mindepth 3 -maxdepth 3 -type d -path '*/prefix/lib' | sort | head -n 1)"
    if [ -z "${lib_src_dir}" ]; then
        bbfatal "Could not locate daphne-server dependency lib directory under ${deps_root}"
    fi

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
