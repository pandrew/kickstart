#!/bin/bash
# Set INSTALL_DRIVE to /dev/sda1 if not already set

[ -z $INSTALL_DRIVE ] && INSTALL_DRIVE="/dev/sda"

BOOT_DRIVE=$INSTALL_DRIVE
AMOUNT_SWAP=1G
PARTITION_BIOS_GPT=1
PARTITION_BOOT=2
PARTITION_SWAP=3
PARTITION_ROOT=4
LABEL_BIOS_GPT=biosgpt
LABEL_BOOT=bootgrub
LABEL_SWAP=swap
LABEL_ROOT=root
MOUNT_PATH=/mnt
BOOT_SYSTEM_PARTITION=/boot/grub

# Prepare system disk
sgdisk -Z ${INSTALL_DRIVE} # DELETE install drive
sgdisk -a 2048 -a ${INSTALL_DRIVE} # CREATING 2048 alignment

# Create system partitions
sgdisk -n ${PARTITION_BIOS_GPT}:0:+2M ${INSTALL_DRIVE} # BIOS GPT needs 2MB
sgdisk -n ${PARTITION_BOOT}:0:+200M ${INSTALL_DRIVE} # BOOT partition
sgdisk -n ${PARTTION_SWAP}:0:+${AMOUNT_SWAP} ${INSTALL_DRIVE} # SWAP partititon
sgdisk -n ${PARTITION_ROOT}:0:0 ${INSTALL_DRIVE} # ROOT partition

# Set partition types
sgdisk -t ${PARTITION_BIOS_GPT}:ef02 ${INSTALL_DRIVE}
sgdisk -t ${PARTITION_BOOT}:8300 ${INSTALL_DRIVE}
sgdisk -t ${PARTITION_SWAP}:8200 ${INSTALL_DRIVE}
sgdisk -t ${PARTITION_ROOT}:8300 ${INSTALL_DRIVE}

# Label partitions
sgdisk -c ${PARTITION_BIOS_GPT}:"${LABEL_BIOS_GPT}" ${INSTALL_DRIVE}
sgdisk -c ${PARTITION_BOOT}:"${LABEL_BOOT}" ${INSTALL_DRIVE}
sgdisk -c ${PARTITION_SWAP}:"${LABEL_SWAP}" ${INSTALL_DRIVE}
sgdisk -c ${PARTITION_ROOT}:"${LABEL_ROOT}" ${INSTALL_DRIVE}

# Make filesystems
mkfs.vfat ${INSTALL_DRIVE}${PARTITION_BOOT}
mkswap ${INSTALL_DRIVE}${PARTITION_SWAP}
swapon ${INSTALL_DRIVE}${PARTITION_SWAP}
mkfs.ex4 ${INSTALL_DRIVE}${PARTITION_ROOT}

# Mount
mkdir -p ${MOUNT_PATH}
mount ${INSTALL_DRIVE}${PARTITION_ROOT} ${MOUNT_PATH}
mkdir -p ${MOUNT_PATH}${BOOT_SYSTEM_PARTITION}
mount -t vfat ${INSTALL_DRIVE}${PARTITION_BOOT} ${MOUNT_PATH}${BOOT_SYSTEM_PARTITION}

cat > ${MOUNT_PATH}/etc/fstab <<FSTAB_EOF
# /etc/fstab: static file system information
#
# <file system>             <dir>       <type>  <options>                   <dump>  <pass>
tmpfs                       /tmp        tmpfs   nodev,nosuid                0       0
#/dev/disk/by-partlabel/${LABEL_BOOT_EFI}       $BOOT_SYSTEM_PARTITION   vfat    rw,relatime,discard     0   2
/dev/disk/by-partlabel/${LABEL_BOOT_GRUB}        $BOOT_SYSTEM_PARTITION   vfat    rw,relatime,discard,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro    0 2
/dev/disk/by-partlabel/${LABEL_SWAP}            none        swap    defaults,discard                    0   0
/dev/disk/by-partlabel/${LABEL_ROOT}            /           ext4    rw,relatime,data=ordered,discard    0   1
FSTAB_EOF

