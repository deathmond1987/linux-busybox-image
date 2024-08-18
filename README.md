# linux-busybox-image
gen base linux image with kernel, busybox and syslinux from source  
  
to run image you need:  
```
git clone https://github.com/deathmond1987/linux-busybox-image.git  
cd ./linux-busybox-image  
docker build . --tag linux:simple  
docker run --name linuxs --privileged linux:simple  
docker cp linuxs:/boot.hdd ./  
        docker rm linuxs  
		qemu-system-x86_64 -drive format=raw,file=./boot.hdd  
		vncviewer 127.0.0.1:5900  
```
and now you ingenerated system
