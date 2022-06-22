#!/bin/bash -x
. scripts/lava-common.sh

sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 remove qemu-system-arm qemu-system

# Build QEMU
git clone -b v5.2.0 --depth 1 https://git.qemu.org/git/qemu.git /tmp/qemu
cd /tmp/qemu 
mkdir -p build
cd build 
TARGETS="aarch64 arm x86_64"
../configure --target-list="$(for tg in $TARGETS; do echo -n ${tg}'-softmmu '; done)" --prefix=/usr 
make -j$(nproc)
make install

qemu-system-aarch64 --version

wget https://people.linaro.org/~maxim.uvarov/ts-firmware-qemu-nonsecure.bin
wget https://people.linaro.org/~maxim.uvarov/ubuntu-seed.iso
wget https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04-live-server-arm64.iso

truncate -s 6G empty_disk.raw
qemu-system-aarch64 -m 2G -smp 2 -nographic -cpu cortex-a57 -machine virt,secure=on \
    -drive if=pflash,unit=0,readonly=off,file=ts-firmware-qemu-nonsecure.bin,format=raw \
    -drive id=p2os,if=none,file=empty_disk.raw,format=raw -device virtio-blk-device,drive=p2os \
    -nographic -net nic,model=virtio,macaddr=DE:AD:BE:EF:36:02 -net user \
    -drive id=seed,if=none,file=ubuntu-seed.iso,format=raw -device virtio-blk-device,drive=seed  \
    -drive id=p3install,if=none,file=ubuntu-22.04-live-server-arm64.iso -device virtio-blk-device,drive=p3install \
    -monitor none
