# image-vhd.bbclass
# (loosly based off bootimg.bbclass Copyright (C) 2004, Advanced Micro Devices, Inc.)
#
# Create an image which can be placed directly onto a harddisk using dd and then
# booted.
#
# This uses syslinux. extlinux would have been nice but required the ext2/3
# partition to be mounted. grub requires to run itself as part of the install
# process.
#
# The end result is a 512 boot sector populated with an MBR and partition table
# followed by an msdos fat16 partition containing syslinux and a linux kernel
# completed by the ext2/3 rootfs.
#
# We have to push the msdos parition table size > 16MB so fat 16 is used as parted
# won't touch fat12 partitions.

# External variables needed

# ${ROOTFS} - the rootfs image to incorporate

IMAGE_DEPENDS_vhd += "hs-vhd-native"

IMAGE_DEPENDS_vhddisk += "hs-vhd-native \
                          dosfstools-native \
                          virtual/kernel \
                          syslinux \
                          syslinux-native \
                          parted-native \
                          mtools-native"

# Using an initramfs is optional. Enable it by setting INITRD_IMAGE.
INITRD_IMAGE ?= ""
INITRD ?= "${@'${DEPLOY_DIR_IMAGE}/${INITRD_IMAGE}-${MACHINE}.cpio.gz' if '${INITRD_IMAGE}' else ''}"
IMAGE_DEPENDS_vhddisk += "${@'${INITRD_IMAGE}:do_rootfs' if '${INITRD_IMAGE}' else ''}"

VM_ROOTFS_TYPE ?= "ext3"

BOOTDD_VOLUME_ID   ?= "boot"
BOOTDD_EXTRA_SPACE ?= "16384"

EFI = "${@bb.utils.contains("MACHINE_FEATURES", "efi", "1", "0", d)}"
EFI_PROVIDER ?= "grub-efi"
EFI_CLASS = "${@bb.utils.contains("MACHINE_FEATURES", "efi", "${EFI_PROVIDER}", "", d)}"

# Include legacy boot if MACHINE_FEATURES includes "pcbios" or if it does not
# contain "efi". This way legacy is supported by default if neither is
# specified, maintaining the original behavior.
def pcbios(d):
    pcbios = bb.utils.contains("MACHINE_FEATURES", "pcbios", "1", "0", d)
    if pcbios == "0":
        pcbios = bb.utils.contains("MACHINE_FEATURES", "efi", "0", "1", d)
    return pcbios

def pcbios_class(d):
    if d.getVar("PCBIOS", True) == "1":
        return "syslinux"
    return ""

PCBIOS = "${@pcbios(d)}"
PCBIOS_CLASS = "${@pcbios_class(d)}"

inherit ${PCBIOS_CLASS}
inherit ${EFI_CLASS}

# Override where syslinux.cfg is stored as do_rootfs cleandirs wipes out the
# location where syslinux.bbclass stores it.
SYSLINUXCFG = "${WORKDIR}/syslinux.cfg"

# Get the build_syslinux_cfg() function from the syslinux class

AUTO_SYSLINUXCFG = "1"
SYSLINUX_PROMPT ?= "0"
SYSLINUX_TIMEOUT ?= "0"
SYSLINUX_LABELS = "boot"
LABELS_append = " ${SYSLINUX_LABELS} "
SYSLINUX_DEFAULT_CONSOLE = "console=ttyS0"
SYSLINUX_ROOT ?= "root=/dev/xvda2"
SYSLINUX_KERNEL_ARGS ?= "ro iommu=soft"


boot_direct_populate() {
	dest=$1
	install -d $dest

	# Install bzImage, initrd, and rootfs.img in DEST for all loaders to use.
	if [ -e ${DEPLOY_DIR_IMAGE}/bzImage ]; then
		install -m 0644 ${DEPLOY_DIR_IMAGE}/bzImage $dest/vmlinuz
	fi

	# initrd is made of concatenation of multiple filesystem images
	if [ -n "${INITRD}" ]; then
		rm -f $dest/initrd
		for fs in ${INITRD}
		do
			if [ -s "${fs}" ]; then
				cat ${fs} >> $dest/initrd
			else
				bbfatal "${fs} is invalid. initrd image creation failed."
			fi
		done
		chmod 0644 $dest/initrd
	fi
}

build_boot_dd() {
	ROOTFS=${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.${VM_ROOTFS_TYPE}${1}
	HDDDIR="${S}/hdd/boot"
	HDDIMG="${S}/hdd.image"
	IMAGE=${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.hdddirect

	if [ ! -e "${SYSLINUXCFG}" ]; then
		bbfatal "syslinux.cfg missing"
	fi

	boot_direct_populate $HDDDIR

	if [ "${PCBIOS}" = "1" ]; then
		syslinux_hddimg_populate $HDDDIR
	fi
	if [ "${EFI}" = "1" ]; then
		efi_hddimg_populate $HDDDIR
	fi

	if [ "x${AUTO_SYSLINUXMENU}" = "x1" ] ; then
		install -m 0644 ${STAGING_DIR}/${MACHINE}/usr/share/syslinux/vesamenu.c32 $HDDDIR/${SYSLINUXDIR}/
		if [ "x${SYSLINUX_SPLASH}" != "x" ] ; then
			install -m 0644 ${SYSLINUX_SPLASH} $HDDDIR/${SYSLINUXDIR}/splash.lss
		fi
	fi

	BLOCKS=`du -bks $HDDDIR | cut -f 1`
	BLOCKS=`expr $BLOCKS + ${BOOTDD_EXTRA_SPACE}`

	# Ensure total sectors is an integral number of sectors per
	# track or mcopy will complain. Sectors are 512 bytes, and we
	# generate images with 32 sectors per track. This calculation is
	# done in blocks, thus the mod by 16 instead of 32.
	BLOCKS=$(expr $BLOCKS + $(expr 16 - $(expr $BLOCKS % 16)))

	# Remove it since mkdosfs would fail when it exists
	rm -f $HDDIMG
	mkdosfs -n ${BOOTDD_VOLUME_ID} -S 512 -C $HDDIMG $BLOCKS
	mcopy -i $HDDIMG -s $HDDDIR/* ::/

	if [ "${PCBIOS}" = "1" ]; then
		syslinux_hdddirect_install $HDDIMG
	fi
	chmod 644 $HDDIMG

	ROOTFSBLOCKS=`du -Lbks ${ROOTFS} | cut -f 1`
	TOTALSIZE=`expr $BLOCKS + $ROOTFSBLOCKS`
	END1=`expr $BLOCKS \* 1024`
	END2=`expr $END1 + 512`
	END3=`expr \( $ROOTFSBLOCKS \* 1024 \) + $END1`

	echo $ROOTFSBLOCKS $TOTALSIZE $END1 $END2 $END3
	rm -rf $IMAGE
	dd if=/dev/zero of=$IMAGE bs=1024 seek=$TOTALSIZE count=1

	parted $IMAGE mklabel msdos
	parted $IMAGE mkpart primary fat16 0 ${END1}B
	parted $IMAGE unit B mkpart primary ext2 ${END2}B ${END3}B
	parted $IMAGE set 1 boot on

	parted $IMAGE print

	awk "BEGIN { printf \"$(echo ${DISK_SIGNATURE} | fold -w 2 | tac | paste -sd '' | sed 's/\(..\)/\\x&/g')\" }" | \
		dd of=$IMAGE bs=1 seek=440 conv=notrunc

	OFFSET=`expr $END2 / 512`
	if [ "${PCBIOS}" = "1" ]; then
		dd if=${STAGING_DATADIR}/syslinux/mbr.bin of=$IMAGE conv=notrunc
	fi

	dd if=$HDDIMG of=$IMAGE conv=notrunc seek=1 bs=512
	dd if=${ROOTFS} of=$IMAGE conv=notrunc seek=$OFFSET bs=512

	cd ${DEPLOY_DIR_IMAGE}
	rm -f ${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.hdddirect
	ln -s ${IMAGE_NAME}.hdddirect ${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.hdddirect
}

python do_bootprep() {
    if 'vhddisk' in d.getVar('IMAGE_FSTYPES', True):
        if d.getVar("PCBIOS", True) == "1":
            bb.build.exec_func('build_syslinux_cfg', d)
        if d.getVar("EFI", True) == "1":
            bb.build.exec_func('build_efi_cfg', d)
}

def generate_disk_signature():
    import uuid

    signature = str(uuid.uuid4())[:8]

    if signature != '00000000':
        return signature
    else:
        return 'ffffffff'


DISK_SIGNATURE := "${@generate_disk_signature()}"


IMAGE_TYPES += "vhd vhddisk"
IMAGE_TYPEDEP_vhd = "${VM_ROOTFS_TYPE}"
IMAGE_TYPEDEP_vhddisk = "${VM_ROOTFS_TYPE}"

tune_image() {
    tune2fs -c -1 -i 0 ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.${1}
    e2fsck -f -y ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.${1} || true
}

IMAGE_CMD_ext2_append() {

    tune_image "ext2"
}

IMAGE_CMD_ext3_append () {

    tune_image "ext3"
}

IMAGE_CMD_ext4_append() {

    tune_image "ext4"
}

create_vhd_image() {
    image_file="${1}"
    suffix="${2:-vhd}"
    vhd_file="${IMAGE_NAME}.rootfs.${suffix}"

    # Round up to even as vhd size must be a multiple of 2 MB.
    tgt_vhd_size=$(du -bms ${image_file}|cut -f 1)
    tgt_vhd_size=$(expr \( \( $tgt_vhd_size + 1 \) / 2 \) \* 2)

    vhd convert ${image_file} ${vhd_file} ${tgt_vhd_size}
}

IMAGE_CMD_vhd = "create_vhd_image ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.${VM_ROOTFS_TYPE}"
IMAGE_CMD_vhddisk = "build_boot_dd; create_vhd_image ${IMAGE_NAME}.hdddirect vhddisk"

addtask bootprep before do_rootfs
