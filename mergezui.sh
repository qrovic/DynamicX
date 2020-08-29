#!/bin/bash

# based in: https://github.com/yukosky/ErfanGSIs/blob/runner/url2GSI.sh

usage()
{
    echo "Usage: <Firmware link>"
    echo -e "\tFirmware link: Firmware download link or local path"
}

if [[ ! -n $1 ]]; then
    echo "-> ERROR!"
    echo " - Enter all needed parameters"
    usage
    exit
fi

echo "- Setting up..."
sudo -E apt-get -qq update
# Some kang of rui's dynamic
sudo -E apt-get -qq install git openjdk-8-jdk wget p7zip-full simg2img unzip zip gzip tar
sudo pip3 install backports.lzma protobuf pycrypto google

URL=$1
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

DOWNLOAD()
{
    aria2c -x16 -j$(nproc) -U "Mozilla/5.0" -d "$PROJECT_DIR/input" -o "tmp.zip" ${URL}
}

echo " "
echo " "
echo "**********************************"
echo "*   ErfanGSI - Dynamic's Runner  *"
echo "*        USE FOR GITHUB          *"
echo "*            @yukosky            *"
echo "**********************************"
echo " "
echo " "

echo "-> Warning: Run it in sudo type."

mkdir -p tmp/input/
mkdir -p source/payload/
cd tmp/input;

echo "-> Downloading firmware, link: $URL"
DOWNLOAD "$URL"

if [ -t "/input/tmp.zip" ]; then
   echo "-> Unzipping downloaded firmware"
   unzip tmp -x compatibility.zip core_map.pb META-INF/* payload_properties.txt
else
   ls -Ralph
   echo "-> Downloaded firmware not detected, exiting."
   exit
fi

if [ -t "payload.bin" ]; then
   echo "-> Move extracted file to payload folder"
   mv *.bin ../../payload/payload.bin
else
   ls -Ralph
   echo "-> Payload binary not detected, exiting."
   exit
fi

echo "-> Extracting the images of payload binary..."
cd ../../payload; python3 payload_dumper.py payload.bin
rm -rf tmp/
cd ../../; mkdir -p tmp/cache/; cd ../../payload/output/

echo "-> Checking if exists Product partition"
if [ -t "product.img" ]; then
   echo "-> Detected Product partition, moving to tmp dir..."
   mv product.img ../../tmp/cache/product.img
else
   echo "-> Not detected, warning: Some firmware have the partition If is dynamic"
fi

echo "-> Checking if exists OnePlus (opproduct) partition"
if [ -t "opproduct.img" ]; then
   echo "-> Detected Product partition, moving to tmp dir..."
   mv opproduct.img ../../tmp/cache/opproduct.img
else
   echo "-> Not detected, maybe cannot boot"
fi

echo "-> Checking if exists System partition"
if [ -t "system.img" ]; then
   echo "-> Detected Product partition, moving to tmp dir..."
   mv system.img ../../tmp/cache/system.img
else
   echo "-> Not detected, cannot continue"
   exit
fi

echo "-> Starting process..."
cd ../../tmp/cache/; mkdir system; mkdir system_new; mkdir opproduct; mkdir product

echo "-> Creating dummy image"
sudo su
dd if=/dev/zero of=system_new.img bs=6k count=1048576

echo "-> Format the dummy image to fix issue"
mkfs.ext4 system_new.img
tune2fs -c0 -i0 system_new.img

echo "-> Mounting dummy and system image"
mount -o loop system_new.img system_new/
mount -o ro system.img system/

echo "-> Task: Copying system files..."
cp -v -r -p system/* system_new/

echo "-> Task: Finished."

sync
echo "-> Umounting system partition"
umount system/

echo "-> Start others process, wait for finish that."
cd system_new
rmdir product
cd ..

mkdir systemop7
mount -ro loop system.img systemop7/
cp -v -r -p systemop7/product system_new/
umount systemop7/

cd system_new/system
rm product
mkdir product

cd ../../
mkdir product
mount -o ro product.img product/
cp -v -r -p product/* system_new/system/product/
sync
umount product/

cd system_new/
if [ ! -d "oneplus"]; then
   echo "-> Warning: OnePlus (opproduct partition) dir not detected"
else
   cd ../
   mkdir opproduct
   mount -o ro opproduct.img opproduct/
   cp -v -r -p opproduct/* system_new/oneplus/
   sync
fi

umount opproduct/
umount system_new/

echo "-> Finish, deleting images files & Uploading"

rm -rf system system.img product opproduct opproduct.img product.img
mv *.img system.img

zip system.zip system.img
curl -sL https://git.io/file-transfer | sh
./transfer gof system.zip
