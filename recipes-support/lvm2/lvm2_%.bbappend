FILESEXTRAPATHS_prepend := "${THISDIR}/${BPN}:"

SRC_URI += " \
    file://0001-apply-obtain_device_list_from_udev-to-all-libudev-us.patch \
    file://volatiles.99_cryptsetup \
"

# meta-oe recipe will already _append the autotools do_install(), and
# do_<something>_append() cannot be overridden...
# So instead, overwrite the files since this is a bbappend it should be done
# after the initial do_install_append()
do_install_append() {
    install -d ${D}${sysconfdir}/default/volatiles
    install -m 0644 ${WORKDIR}/volatiles.99_cryptsetup ${D}${sysconfdir}/default/volatiles/99_cryptsetup
}

FILES_${PN} += " \
    ${sysconfdir}/default/volatiles \
"
RDEPENDS_${PN} += " \
    bash \
"
