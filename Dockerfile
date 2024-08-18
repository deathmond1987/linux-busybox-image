FROM alpine:edge
ENV INITFS_FILE=initfs.cpio KERNEL=bzImage LOCALVERSION=-vasyan_edition
# установка зависимостей необходимых для сборки ядра
# git           - система контроля версий. им мы будем забирать исходный код
# vim           - для редактирования конфигов
# make          - система сброки
# gcc           - набор компиляторов
# ncurses       - тулкит для построения tui
# flex          - лексический анализатор
# bison         - генератор синтаксических анализаторов
# bc            - калькулятор
# cpio          - архиватор
# linux-headers - заголовочные файлы ядра
# musl-dev      - заголовочные файлы musl
# elfutils-dev  - заголовочные файлы для работы с эльфами и дворфами (серьезно. ELF и DWARF)
# perl          - ну perl
# openssl-dev   - заголовочные файлы openssl
 
RUN apk add --update --no-cache \
                               git \
                               bzip2 \
                               vim \
                               make \
                               gcc \
                               flex \
                               bison \
                               bc \
                               cpio \
                               linux-headers \
                               musl-dev \
                               elfutils-dev \
                               perl \
                               openssl-dev

# clone kernel sources
RUN git clone --depth 1 https://github.com/torvalds/linux.git
# busydox awk not compactible
RUN apk add gawk
# busybox diff not compactible
RUN apk add diffutils
# busybox find not compactible
RUN apk add findutils
# cd to linux source
WORKDIR linux
# we need to build x86_64 kernel
ENV ARCH=x86_64
# create default kernel config
RUN make defconfig
# build kernel with default config
RUN make -j$(nproc)
RUN make -j$(nproc) -C . M=$PWD modules
RUN ls -la arch/x86/boot/

# create dir with new OS
RUN mkdir -p /new_os
# copy kernel image to new OS
RUN cp arch/x86/boot/${KERNEL} /new_os/
# copy example kernel module
RUN cp /linux/drivers/thermal/intel/x86_pkg_temp_thermal.ko /new_os/LVM2.ko
WORKDIR /
# clone busybox sources
RUN git clone --depth 1 https://git.busybox.net/busybox
WORKDIR /busybox
# create output dir
RUN mkdir -p obj/busybox-x86
# create default config
RUN make O=obj/busybox-x86 defconfig
# set build static
RUN sed -i '/# CONFIG_STATIC is not set/c\CONFIG_STATIC=y' obj/busybox-x86/.config
#RUN echo "CONFIG_STATIC=y" >> obj/busybox-x86/.config
WORKDIR obj/busybox-x86
# build busybox
RUN make -j$(nproc)
RUN ls -la ./
# create busybox work dir
RUN mkdir -p /new_os/initramfs
# install busybox to work dir
RUN make CONFIG_PREFIX=/new_os/initramfs install
RUN ls -la /new_os/initramfs
# remove linuxrc
RUN rm /new_os/initramfs/linuxrc

# create init script
COPY <<EOF /new_os/initramfs/init
#!/bin/sh
/bin/sh
EOF

# set exec permissions
RUN chmod +x /new_os/initramfs/init

# mount pseudofs
COPY <<EOF /new_os/initramfs/work.sh
#!/bin/sh
mkdir -p /dev /sys /proc /mnt
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mount /dev/sda /mnt
EOF
RUN chmod +x /new_os/initramfs/work.sh

RUN ls -la /new_os/initramfs

WORKDIR /new_os/initramfs/
# create initramfs
RUN find . | cpio -o -H newc > ../${INITFS_FILE}

# create raw image disk
RUN dd if=/dev/zero of=/boot.hdd bs=1M count=50
# add fat fs  needed packages
RUN apk add dosfstools util-linux
RUN mkfs -t fat /boot.hdd

# add syslinux
RUN apk add syslinux
# install syslinux to image
RUN syslinux /boot.hdd

# create mountpoint to mount image
RUN mkdir -p /mount
# add root payload script
COPY --chmod=700 script.sh /script.sh
# run script
CMD /script.sh
RUN echo -e "!!! YOU NEED TAG THIS IMAGE: docker build . --tag linux:simple !!!\n"
RUN echo -e "!!! AND RUN WITH: docker run --name linuxs --privileged linux:simple"