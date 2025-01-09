#!/usr/bin/env ash
set -e
set -x
## move to project dir
cd /new_os/

## mount disk image
mount /boot.hdd /mount

## copy to mount image all files

## create syslinux config dir
mkdir -p /mount/boot/syslinux
## copy bzImage to /boot
cp ${KERNEL} /mount/boot
## copy initramfs to /boot
cp ${INITFS_FILE} /mount/boot
## create kernel modules dir
mkdir -p /mount/usr/lib/modules/version_name/kernel/drivers/md/
## copy example kernel module to that dir
cp LVM2.ko /mount/usr/lib/modules/version_name/kernel/drivers/md/

## gen syslinux conf
echo "SERIAL 0
PROMPT 1
TIMEOUT 50
DEFAULT invalid

LABEL invalid-linux
MENU LABEL invalid-linux
LINUX /boot/${KERNEL}
INITRD /boot/initfs.cpio" > /mount/boot/syslinux/syslinux.cfg

## show created filesystem tree
tree /mount

## unmount disk image
umount /mount

## show next steps help
echo "

NEXT :
  copy /boot.hdd            : docker cp linuxs:/boot.hdd ./
  remove image              : docker rm linuxs
  run boot.hdd in qemu      : qemu-system-x86_64 -drive format=raw,file=./boot.hdd
  vnc to default qemu port  : vncviewer 127.0.0.1:5900
"
