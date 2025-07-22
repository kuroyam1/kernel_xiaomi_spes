#!/bin/bash

#
# Configure defualt value:
# CPU = use all cpu for build
# CHAT = chat telegram for push build. use id.
#
CPU=$(nproc --all)
SUBNAME="none"

sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git cmake binutils make bc bison \
    libssl-dev curl zip kmod cpio flex elfutils libssl-dev device-tree-compiler \
    ca-certificates python3 xz-utils libc6-dev aria2 ccache zstd lld clang wget \
    inetutils-tools libncurses5-dev libelf-dev gcc-multilib gcc-multilib libtool \
    binutils-aarch64-linux-gnu


#
# Add support cmd:
# --cpu= for cpu used to compile
# --key= for bot key used to push.
# --name= for custom subname of kernel
#
config() {

    arg1=${1}

    case ${1} in
        "--cpu="* )
            CPU="--cpu="
            CPU=${arg1#"$CPU"}
        ;;
        "--key="* )
            KEY="--key="
            KEY=${arg1#"$KEY"}
        ;;
        "--name="* )
            SUBNAME="--name="
            SUBNAME=${arg1#"$SUBNAME"}
        ;;
    esac
}

arg1=${1}
arg2=${2}
arg3=${3}

config ${1}
config ${2}
config ${3}

echo "Config for resource of environment done."
echo "CPU for build: $CPU"
echo "NAME of kernel: $SUBNAME"

# start build date
DATE=$(date +"%Y%m%d-%H%M")

# Compiler type
TOOLCHAIN_DIRECTORY="tc"

# Build defconfig
DEFCONFIG="vendor/spes-perf_defconfig"

# Check for compiler
if [ ! -d "$TOOLCHAIN_DIRECTORY" ]; then
    mkdir $TOOLCHAIN_DIRECTORY/custom-clang -p
    wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-13.0.0_r13/clang-r450784d.tar.gz -O file.tar.gz
    tar -xzf file.tar.gz -C $TOOLCHAIN_DIRECTORY/custom-clang
fi

rm -rf KernelSU-Next
git submodule update --init --recursive
sed -i '16s/default y/default n/' KernelSU-Next/kernel/Kconfig
sed -n '16p' KernelSU-Next/kernel/Kconfig

if [ -d "$TOOLCHAIN_DIRECTORY/custom-clang" ]; then
    echo -e "${bldgrn}"
    echo "clang is ready"
    echo -e "${txtrst}"
else
    echo -e "${red}"
    echo "Need to download clang"
    echo -e "${txtrst}"
    exit
fi

#
# Build start with clang
#
echo 'alias grep="/usr/bin/grep $GREP_OPTIONS"' >> ~/.bashrc
echo 'unset GREP_OPTIONS' >> ~/.bashrc
source ~/.bashrc

export PATH="$(pwd)/$TOOLCHAIN_DIRECTORY/custom-clang/bin:${PATH}"
make O=out CC=clang ARCH=arm64 $DEFCONFIG
make -j$CPU O=out \
			ARCH=arm64 \
			CC=clang \
			CROSS_COMPILE=aarch64-linux-gnu- \
			CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
			AR=llvm-ar \
			NM=llvm-nm \
			OBJCOPY=llvm-objcopy \
			OBJDUMP=llvm-objdump \
			STRIP=llvm-strip \
			LLVM=1 \
			LLVM_IAS=1 \
			Image.gz \
			dtbo.img


# Download anykernel for flash kernel
git clone --depth=1 https://github.com/binhvo7794/AnyKernel3 -b spes anykernel


if [ $SUBNAME == "none" ]; then
    SUBNAME=$DATE
fi

cp out/arch/arm64/boot/Image.gz anykernel
cp out/arch/arm64/boot/dtbo.img anykernel
cd anykernel
zip -r9 ../Sus-$SUBNAME.zip * -x .git README.md *placeholder
curl bashupload.com -T ../Sus-$SUBNAME.zip
cd ..
rm -rf anykernel
echo "The path of the kernel.zip is: $(pwd)/Sus-$SUBNAME.zip"

