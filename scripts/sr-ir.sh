#!/bin/bash
. scripts/lava-common.sh

# urls
acs_img='ir_acs_live_image.img'
acs_url='https://people.linaro.org/~ilias.apalodimas/qemu/debian/'"$acs_img"
post_url='https://archive.validation.linaro.org/artifacts/team/systemready/'

# final log files
log_file_part='/media/acs_results/sct_results/Overall/Summary'
ekl="$log_file_part"'.ekl'
log="$log_file_part"'.log'

VARIABLES="{$VARIABLES:-https://people.linaro.org/~ilias.apalodimas/images/ubuntu-21.04/variables.img}"
UBOOT="{$UBOOT:-https://people.linaro.org/~ilias.apalodimas/qemu/debian/u-boot.bin}"

echo "UBOOT: ${UBOOT}"
echo "VARIABLES: ${VARIABLES}"

wget "$acs_url"
wget ${VARIABLES}
wget ${UBOOT}

# Ordering matters here keep variables.img first
tmux new-session -d -s qemu \
	"qemu-system-aarch64 \
    -bios u-boot.bin \
    -machine virt \
    -cpu cortex-a57 -m 4G \
    -nographic -no-acpi \
    -drive id=disk0,file=variables.img,if=none,format=raw \
    -device virtio-blk-device,drive=disk0 \
    -drive id=disk1,file=$acs_img,if=none,format=raw \
    -device virtio-blk-device,drive=disk1"

echo '########################################'
echo '# Checking QEMU ACS for completion ... #'
echo '########################################'

part=$(losetup -f -P -r --show $acs_img)'p2'
[ -z "$part" ] && lava_result 'MOUNT_LOOPBACK' 'FAILED' 'yes'

el=0
while true; do
	sudo mount "$part" /media > /dev/null 2>&1
	# Since there's no indication in SCT, grep for a very late entry in FWTS
	# logs (FWTS executes after SCT)
	stop_compl=$(grep 'Other failures' /media/acs_results/fwts/FWTSResults.log 2>/dev/null)
	[ -n "$stop_compl" ] && echo "Found SCT logs. Parsing..." && break
	stop_qemu=$(pidof qemu-system-aarch64)
	[ -z "$stop_qemu" ] && lava_result 'QEMU_PROCESS' 'FAILED' 'yes' && break

	sudo umount /media > /dev/null 2>&1
	echo "Test running for $((el/60)) minutes ..."
	sleep 120
	el=$((el+120))
done

#git clone --depth=1 https://gitlab.arm.com/systemready/edk2-test-parser
git clone --branch vincent/master https://gitlab.arm.com/systemready/edk2-test-parser
cd edk2-test-parser
./parser.py "$ekl" \
	/media/acs_results/sct_results/Sequence/EBBR.seq \
	--filter "x['result'] in ['DROPPED', 'FAILURE', 'WARNING']" --uniq \
	--fields 'count,result,name' --print

# Get the key
lava_test_dir="$(find /lava-* -maxdepth 0 -type d | grep -E '^/lava-[0-9]+' 2>/dev/null | sort | tail -1)"
[ -n "$lava_test_dir" ] && . $lava_test_dir/secrets

# store files
ekl=$(curl -F "path=@$ekl" -F "token=$API_KEY" "$post_url")
log=$(curl -F "path=@$log" -F "token=$API_KEY" "$post_url")
final_dir=$(echo $ekl | awk 'BEGIN{FS=OFS="/"}NF--')
final_dir="$final_dir"'/'

# used for prints
title='Download Logs'
url_num_char=${#final_dir}
title_num_char=${#title}

# pretty print logs location
printc=$(printf '%*s' "$url_num_char" | tr ' ' '#')
start=$(((url_num_char-title_num_char)/2))
echo "$printc" | awk -v start="$start" \
	-v rep="$title_num_char" \
	-v title="$title" \
	'{target=substr($0,0,rep); gsub(/#############/,title,target); \
	trail=substr($0,0,start)
	print trail target trail}'
echo "$final_dir"
echo "$printc"

sudo umount /media > /dev/null 2>&1
sudo losetup -D > /dev/null 2>&1
