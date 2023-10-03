#!/bin/bash
 
# You may need to install the following packages
# apt update -y
# apt install -y wget git bc bison flex libssl-dev make libc6-dev libncurses5-dev crossbuild-essential-$ARCH
 
KERNEL_VERSION=6.1
RT_PATCH_VERSION=$KERNEL_VERSION.26-rt8
COMMIT_HASH=dbcb82357ef21be47841ba39d117b626d715af31
DEFCONFIG=bcm2711_defconfig
ARCH=arm64
TARGET=aarch64-linux-gnu
KERNEL_NAME=kernel8
 
KERNEL_BRANCH=rpi-$KERNEL_VERSION.y
COMPILER=$TARGET-
 
# All work will be done in $PWD/rtkernel.  The final result will be packaged as $PWD/rtkernel/result
WORK_DIR=`pwd`/rtkernel
rm -rf $WORK_DIR
mkdir $WORK_DIR
cd $WORK_DIR
 
# download the kernel
git clone --depth=1 --branch $KERNEL_BRANCH https://github.com/raspberrypi/linux.git
 
# download the RT patch
wget http://cdn.kernel.org/pub/linux/kernel/projects/rt/$KERNEL_VERSION/older/patch-$RT_PATCH_VERSION.patch.gz
gunzip patch-$RT_PATCH_VERSION.patch.gz
 
# Need this to get precisely the correct kernel version
cd linux
git fetch origin $COMMIT_HASH
git reset --hard $COMMIT_HASH
 
# Patch the kernel
patch -p1 < ../patch-$RT_PATCH_VERSION.patch
 
# Prepare configuration
make ARCH=$ARCH CROSS_COMPILE=$COMPILER $DEFCONFIG
 
# Configure to use the "Fully Preemptible Kernel (Real-Time)" kernel
./scripts/config --set-val CONFIG_PREEMPT_RT y
./scripts/config --set-val CONFIG_RCU_BOOST y
./scripts/config --set-val CONFIG_RCU_BOOST_DELAY 500
./scripts/config --set-val CONFIG_RCU_NOCB_CPU y
./scripts/config --set-val CONFIG_NO_HZ_FULL y
./scripts/config --set-val CONTEXT_TRACKING_USER_FORCE n
./scripts/config --set-val RCU_NOCB_CPU_DEFAULT_ALL n
./scripts/config --set-val RCU_NOCB_CPU_CB_BOOST y

# Set the local version to include your name
./scripts/config --set-str CONFIG_LOCALVERSION "-GijsS"

# Compile
make -j32 ARCH=$ARCH CROSS_COMPILE=$COMPILER Image.gz modules dtbs
 
# copy assets to the root file system
make ARCH=$ARCH CROSS_COMPILE=$COMPILER INSTALL_MOD_PATH=modules_to_install modules_install
 
# Out of linux, out of work_dir
cd ../../
 
# copy assets to the $PROJECT_DIR/result directory
RESULT_DIR=$WORK_DIR/result
mkdir -p $RESULT_DIR/boot/overlays
cp ${WORK_DIR}/linux/arch/$ARCH/boot/Image.gz ${RESULT_DIR}/boot/$KERNEL_NAME.img
cp -r ${WORK_DIR}/linux/modules_to_install/lib/* ${RESULT_DIR}/lib/
cp ${WORK_DIR}/linux/arch/$ARCH/boot/dts/broadcom/*.dtb ${RESULT_DIR}/boot/
cp ${WORK_DIR}/linux/arch/$ARCH/boot/dts/overlays/*.dtb* ${RESULT_DIR}/boot/overlays/
cp ${WORK_DIR}/linux/arch/$ARCH/boot/dts/overlays/README ${RESULT_DIR}/boot/overlays/

