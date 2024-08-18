#!/usr/bin/env ash
set -ex

# move to project dir
cd /new_os/

# mount disk image
echo "mount /boot.hdd..."
mount /boot.hdd /mount

# copy to mount image all files
mkdir -p /mount/boot/syslinux
echo "copy linux kernel..."
cp ${KERNEL} /mount/boot
echo "copy init..."
cp ${INITFS_FILE} /mount/boot
mkdir -p /mount/usr/lib/modules/version_name/kernel/drivers/md/
cp LVM2.ko /mount/usr/lib/modules/version_name/kernel/drivers/md/
echo "creating syslinux conf..."

# gen syslinux conf
echo "SERIAL 0
PROMPT 1
TIMEOUT 50
DEFAULT invalid

LABEL invalid
MENU LABEL invalid
LINUX /boot/${KERNEL}
INITRD /boot/initfs.cpio" > /mount/boot/syslinux/syslinux.cfg

tree /mount

#unmount disk image
echo "unmount /boot.hdd"
umount /mount

echo "raw image created!

NEXT :
  copy /boot.hdd            : docker cp linuxs:/boot.hdd ./
  remove image              : docker rm linuxs
  run boot.hdd in qemu      : qemu-system-x86_64 -drive format=raw,file=./boot.hdd
  vnc to default qemu port  : vncviewer 127.0.0.1:5900
"
