require recipes/ghc/ghc-xclib.inc

DESCRIPTION = "haskell websocket library"
LICENSE = "LGPLv2.1"
LIC_FILES_CHKSUM = "file://../COPYING;md5=321bf41f280cf805086dd5a720b37785"
DEPENDS += "ghc-mtl ghc-binary"
RDEPENDS += "glibc-gconv-utf-32 ghc-runtime-native"

PV = "0+git${SRCPV}"

SRCREV = "${AUTOREV}"
SRC_URI = "git://${OPENXT_GIT_MIRROR}/xclibs.git;protocol=${OPENXT_GIT_PROTOCOL};branch=${OPENXT_BRANCH}"
S = "${WORKDIR}/git/xchwebsocket"
