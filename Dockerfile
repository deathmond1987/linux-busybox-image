## build static file manager 
#FROM alpine:latest as lf
#RUN apk add --no-cache go
#RUN env CGO_ENABLED=0 go install -ldflags="-s -w" github.com/gokcehan/lf@latest
FROM alpine:3.19 AS mc-build

RUN apk add --no-cache \
    build-base glib-dev glib-static ncurses-dev ncurses-static \
    ncurses-terminfo-base pcre2-dev gettext-dev gettext-static \
    zlib-dev zlib-static libssh2-dev libssh2-static openssl-dev \
    openssl-libs-static tar xz findutils bash

WORKDIR /build
ADD http://ftp.midnight-commander.org/mc-4.8.31.tar.xz /build/mc.tar.xz
RUN tar -xf mc.tar.xz --strip-components=1

RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --without-x \
    --with-screen=ncurses \
    --enable-vfs-sftp \
    --disable-nls \
    --without-man \
    --disable-doxygen

RUN make -j$(nproc) || true
RUN make install || true

# Ручная статическая линковка
RUN gcc -static -no-pie -o /usr/bin/mc_pure_static \
    $(find src lib -name "*.o" ! -path "*/.libs/*" ! -name "mc.o" ! -name "cons.saver.o" ! -name "man2hlp.o" ! -name "main.o") \
    src/main.o \
    -Wl,--start-group \
    -lglib-2.0 -lpcre2-8 -lncursesw -lintl -lz -lssh2 -lssl -lcrypto \
    -Wl,--end-group && \
    strip /usr/bin/mc_pure_static

RUN <<EOF cat > /gotar.ini
[skin]
    description = GoTaR @PLD Linux

[Lines]
    horiz = ─
    vert = │
    lefttop = ┌
    righttop = ┐
    leftbottom = └
    rightbottom = ┘
    topmiddle = ┬
    bottommiddle = ┴
    leftmiddle = ├
    rightmiddle = ┤
    cross = ┼
    dhoriz = ─
    dvert = │
    dlefttop = ┌
    drighttop = ┐
    dleftbottom = └
    drightbottom = ┘
    dtopmiddle = ┬
    dbottommiddle = ┴
    dleftmiddle = ├
    drightmiddle = ┤

[core]
    _default_ = lightgray;black
    selected = white;blue
    marked = brightred;
    markselect = yellow;
    gauge = ;brown
    input = brightgreen;
    disabled = gray;blue
    reverse = brightgreen;blue
    header = brightred;
    inputhistory =
    commandhistory =
    shadow = gray;black

[dialog]
    _default_ = brightcyan;blue
    dfocus = brightred;black
    dhotnormal = brightred;
    dhotfocus = yellow;black
    dtitle = brightred;

[error]
    _default_ = white;red
    errdfocus = brightgreen;blue
    errdhotnormal = yellow;
    errdhotfocus = yellow;blue
    errdtitle = yellow;

[filehighlight]
    directory = brightcyan;
    executable = brightgreen;
    symlink = red;
    hardlink =
    stalelink = yellow;blue
    device = green;
    special = brightblue;
    core = red;
    temp = gray;
    archive = cyan;
    doc = brown;
    source = green;
    media = white;
    graph = magenta;
    database = ;

[menu]
    _default_ = brightgreen;black
    menusel = brightcyan;blue
    menuhot = brightred;
    menuhotsel = yellow;
    menuinactive = lightgray;

[popupmenu]
    _default_ = brightgreen;black
    menusel = brightcyan;blue
    menutitle = brightcyan;black

[buttonbar]
    hotkey = lightgray;black
    button = white;blue

[statusbar]
    _default_ = white;blue

[help]
    _default_ = brightred;black
    helpitalic = brightcyan;
    helpbold = brightgreen;
    helplink = white;
    helpslink = yellow;blue
    helptitle = brightgreen;

[editor]
    _default_ = lightgray;black
    editbold = yellow;blue
    editmarked = brightgreen;red
    editwhitespace = brightblue;blue
    editnonprintable = ;black
    editlinestate = brightgreen
    bookmark = white;red
    bookmarkfound = black;green
    editrightmargin = brightblue;blue
#    editbg =
#    editframe =
    editframeactive = white;
    editframedrag = green;

[viewer]
    _default_ = lightgray;black
    viewbold = brightred;black
    viewunderline = brightgreen;black
    viewselected = yellow;black

[diffviewer]
    _default_ = lightgray;black
    added = brightgreen;
    changedline = cyan;
    changednew = yellow;
    changed = ;brown
    removed = ;blue
    error = white;red

[widget-panel]
    filename-scroll-left-char = {
    filename-scroll-right-char = }

[widget-editor]
    window-state-char = *
    window-close-char = X"
EOF

FROM alpine:edge
## need rework
## LOCALVERSION - change second kernel name
## ARCH - kernel target architecture
ENV INITFS_FILE=initfs.cpio KERNEL=bzImage LOCALVERSION=-noname_edition ARCH=x86_64
## установка зависимостей необходимых для сборки ядра
## git           - система контроля версий. им мы будем забирать исходный код
## vim           - для редактирования конфигов
## make          - система сброки
## gcc           - набор компиляторов
## ncurses       - тулкит для построения tui
## flex          - лексический анализатор (нужен для определенной части кода)
## bison         - генератор синтаксических анализаторов (нужен для определенной части кода)
## bc            - калькулятор
## cpio          - архиватор
## linux-headers - заголовочные файлы ядра
## musl-dev      - заголовочные файлы musl
## elfutils-dev  - заголовочные файлы для работы с эльфами и дворфами (серьезно. ELF и DWARF)
## perl          - ну perl
## openssl-dev   - заголовочные файлы openssl

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

## clone kernel sources
RUN git clone --depth 1 https://github.com/torvalds/linux.git
## this packages in alpine busybox not compactible with kernel building
RUN apk add gawk diffutils findutils
## cd to linux source
WORKDIR linux
## create default kernel config
RUN make defconfig
## build kernel with default config
RUN make -j$(nproc)
## build modules
## i use one module to explain why modules need to be in initfs
RUN make -j$(nproc) -C . M=$PWD modules
RUN ls -la arch/x86/boot/

## create dir with new OS
RUN mkdir -p /new_os
## copy kernel image to new OS
RUN cp arch/x86/boot/${KERNEL} /new_os/
## copy example kernel module
RUN cp /linux/drivers/thermal/intel/x86_pkg_temp_thermal.ko /new_os/LVM2.ko
WORKDIR /
## clone busybox sources
RUN git clone --depth 1 https://git.busybox.net/busybox
WORKDIR /busybox
## create output dir
RUN mkdir -p obj/busybox-x86
## create default config
RUN make O=obj/busybox-x86 defconfig
## set build static
RUN sed -i '/# CONFIG_STATIC is not set/c\CONFIG_STATIC=y' obj/busybox-x86/.config
## busybox is not ready for new linux headers
RUN sed -i '/CONFIG_TC=y/c\CONFIG_TC=n' obj/busybox-x86/.config
WORKDIR obj/busybox-x86
## build busybox
RUN make -j$(nproc)
RUN ls -la ./
## create busybox work dir
RUN mkdir -p /new_os/initramfs
## install busybox to work dir
RUN make CONFIG_PREFIX=/new_os/initramfs install
RUN ls -la /new_os/initramfs
## remove linuxrc
RUN rm /new_os/initramfs/linuxrc

## add dependency-free file manager
#COPY --from=lf /root/go/bin/lf /new_os/initramfs/bin/
COPY --from=mc-build /usr/bin/mc_pure_static /new_os/initramfs/bin/mc
COPY --from=mc-build /gotar.ini /new_os/initramfs/gotar.ini

## create init script
COPY <<EOF /new_os/initramfs/init
#!/bin/sh
/bin/sh
EOF

## set exec permissions
RUN chmod +x /new_os/initramfs/init

## mount pseudofs
COPY <<EOF /new_os/initramfs/work.sh
#!/bin/sh
mkdir -p /dev /sys /proc /mnt
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
## mount hdd itlself to /mnt
mount /dev/sda /mnt
## show disk usage and kernel name
echo "disk usage:"
du -hs * | sort -h
uname -a
## user need to run lf
export USER=root
## escape from /dev/terminal to /dev/tty1
## this also need to run lf
export MC_SKIN=/gotar.ini
exec setsid sh -c 'exec sh </dev/tty1 >/dev/tty1 2>&1'
EOF

RUN chmod +x /new_os/initramfs/work.sh

RUN ls -la /new_os/initramfs

WORKDIR /new_os/initramfs/
## create initramfs
RUN find . | cpio -o -H newc > ../${INITFS_FILE}

## create raw image disk
RUN dd if=/dev/zero of=/boot.hdd bs=1M count=30
## add fat fs  needed packages
RUN apk add dosfstools util-linux
RUN mkfs -t fat /boot.hdd

## add syslinux
RUN apk add syslinux
## install syslinux to image
RUN syslinux /boot.hdd

## create mountpoint to mount image
RUN mkdir -p /mount
## add root payload script
COPY --chmod=700 script.sh /script.sh
## run script
CMD /script.sh
RUN echo -e "!!! YOU NEED TAG THIS IMAGE: docker build . --tag linux:simple !!!\n"
RUN echo -e "!!! AND RUN WITH: docker run --name linuxs --privileged linux:simple"
