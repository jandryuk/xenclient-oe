DESCRIPTION = "Linux kernel for OpenXT service VMs."

# Use the one from meta-openembedded/meta-oe
require recipes-kernel/linux/linux.inc
require recipes-kernel/linux/linux-openxt.inc
DEPENDS += "rsync-native"

PV_MAJOR = "${@"${PV}".split('.', 3)[0]}"

FILESEXTRAPATHS_prepend := "${THISDIR}/patches:${THISDIR}/defconfigs:"
SRC_URI += "${KERNELORG_MIRROR}/linux/kernel/v${PV_MAJOR}.x/linux-${PV}.tar.xz;name=kernel \
    file://bridge-carrier-follow-prio0.patch \
    file://privcmd-mmapnocache-ioctl.patch \
    file://xenkbd-tablet-resolution.patch \
    file://acpi-video-delay-init.patch \
    file://skb-forward-copy-bridge-param.patch \
    file://dont-suspend-xen-serial-port.patch \
    file://extra-mt-input-devices.patch \
    file://tpm-log-didvid.patch \
    file://blktap2.patch \
    file://export-for-xenfb2.patch \
    file://intel-amt-support.patch \
    file://disable-csum-xennet.patch \
    file://pci-pt-move-unaligned-resources.patch \
    file://pci-pt-flr.patch \
    file://realmem-mmap.patch \
    file://netback-skip-frontend-wait-during-shutdown.patch \
    file://xenbus-move-otherend-watches-on-relocate.patch \
    file://netfront-support-backend-relocate.patch \
    file://konrad-ioperm.patch \
    file://fbcon-do-not-drag-detect-primary-option.patch \
    file://usbback-base.patch \
    file://hvc-kgdb-fix.patch \
    file://pciback-restrictive-attr.patch \
    file://thorough-reset-interface-to-pciback-s-sysfs.patch \
    file://tpm-tis-force-ioremap.patch \
    file://netback-vwif-support.patch \
    file://gem-foreign.patch \
    file://xen-txt-add-xen-txt-eventlog-module.patch \
    file://xenpv-no-tty0-as-default-console.patch \
    file://xsa-155-qsb-023-add-RING_COPY_RESPONSE.patch \
    file://xsa-155-qsb-023-xen-blkfront-make-local-copy-of-response-before-usin.patch \
    file://xsa-155-qsb-023-xen-blkfront-prepare-request-locally-only-then-put-i.patch \
    file://xsa-155-qsb-023-xen-netfront-add-range-check-for-Tx-response-id.patch \
    file://xsa-155-qsb-023-xen-netfront-copy-response-out-of-shared-buffer-befo.patch \
    file://xsa-155-qsb-023-xen-netfront-do-not-use-data-already-exposed-to-back.patch \
    file://defconfig \
    "

LIC_FILES_CHKSUM = "file://COPYING;md5=bbea815ee2795b2f4230826c0c6b8814"
SRC_URI[kernel.md5sum] = "f1ae5618270676470e6b2706c61d909b"
SRC_URI[kernel.sha256sum] = "669a74f4aeef07645061081d9c05d23216245702b4095afb3d957f79098f0daf"

# Backport for new file in 5.2+
FILES_kernel-base += "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/modules.builtin.modinfo"

do_make_scripts() {
	unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
	make CC="${KERNEL_CC}" LD="${KERNEL_LD}" AR="${KERNEL_AR}" \
		-C ${STAGING_KERNEL_DIR} O=${STAGING_KERNEL_BUILDDIR} scripts prepare
}

do_shared_workdir_append() {
	if [ -x scripts/mod/modpost ]; then
		mkdir -p ${kerneldir}/scripts/mod
		cp scripts/mod/modpost ${kerneldir}/scripts/mod
	fi
}
