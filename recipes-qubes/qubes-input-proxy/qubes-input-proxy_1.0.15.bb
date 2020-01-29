SUMMARY = "Qubes Simple input events proxy"
LICENSE="GPLv2+"
LIC_FILES_CHKSUM = "file://debian/copyright;beginline=8;endline=22;md5=e4f60d1e5c91bab4e89cc83acb62bb9b"

SRC_URI = " \
	git://github.com/QubesOS/qubes-app-linux-input-proxy.git \
	file://uinput.conf \
"
SRCREV = "d3269f32b51b38e9ecd862de25a694959a42aca1"

S = "${WORKDIR}/git"

PACKAGES =+ "${PN}-sender ${PN}-receiver"

FILES_${PN}-sender = "${bindir}/input-proxy-sender"
FILES_${PN}-receiver = "\
    ${bindir}/input-proxy-receiver \
    ${sysconfdir}/modules-load.d/ \
"

do_install() {
    oe_runmake -C src install DESTDIR=${D}

    install -d ${D}${sysconfdir}/modules-load.d/
    install -m 0644 ${WORKDIR}/uinput.conf ${D}${sysconfdir}/modules-load.d/
}
