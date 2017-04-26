#!/bin/bash
#

VERSION=`cat ./VERSION`
CUR_PATH=`pwd`
DATETIME=`date -d today +"%Y%m%d%H%M"`
DIST=`rpm -E %{dist}`
ISO_NAME=ISCLOUDER-Center-V${VERSION}-${DATETIME}.iso
SRC_PATH=$CUR_PATH/CentOS
CENTOS_ISO=/root/CentOS-7-x86_64-Minimal-1511.iso
ISO_PATH=$CUR_PATH/iso
TMP_PATH=$CUR_PATH/tmp
MED_PATH=$CUR_PATH/media

if [ -d $SRC_PATH ]; then umount $SRC_PATH; rm -rf $SRC_PATH; fi
if [ -d $ISO_PATH ]; then rm -rf $ISO_PATH; fi
if [ -d $TMP_PATH ]; then rm -rf $TMP_PATH; fi
if [ -d $MED_PATH ]; then rm -rf $MED_PATH; fi

mkdir -p $SRC_PATH
mkdir -p $ISO_PATH
mkdir -p $TMP_PATH
mkdir -p $MED_PATH
mount -o loop $CENTOS_ISO $SRC_PATH
[ $? != 0 ] && exit 1

copy_rpms() {
    cd $SRC_PATH
    rsync -av --exclude=Packages . $TMP_PATH
    mkdir -p $TMP_PATH/Packages

    cp $CUR_PATH/rpms/* $TMP_PATH/Packages/
}

build_private() {
    cd $CUR_PATH/isclouder-private
    ./mkrpm.sh
    [ $? != 0 ] && exit 1
    for pkg in `find ./rpmbuild/RPMS/ -name "*.rpm"`; do cp ${pkg} $TMP_PATH/Packages/; done
    rm -rf ./rpmbuild
}


create_yum() {
    cp $CUR_PATH/script/c7-x86_64-comps.xml $TMP_PATH/repodata/c7-x86_64-comps.xml
    cd $TMP_PATH/
    declare -x discinfo=`head -1 .discinfo`
    createrepo -g repodata/c7-x86_64-comps.xml ./
}

change_isolinux_cfg() {
    rm -rf $TMP_PATH/isolinux/isolinux.cfg
    cp $CUR_PATH/script/isolinux.cfg $TMP_PATH/isolinux/
    cp $CUR_PATH/script/isclouder.cfg $TMP_PATH/isolinux/
    sed -i "s/PRODUCT_NAME/ISCLOUDER-Center ${VERSION} (${DATETIME})/" $TMP_PATH/isolinux/isolinux.cfg
}

change_initrd() {
    cd $SRC_PATH/isolinux/
    if [ -d /tmp/initrd ]; then rm -rf /tmp/initrd; fi
    if [ -f /tmp/initrd.img ]; then rm -rf /tmp/initrd.img; fi
    mkdir /tmp/initrd
    cp initrd.img /tmp/initrd/
    cd /tmp/initrd/
    xz -dc initrd.img | cpio -id
    rm -rf initrd.img

    echo [Main] > ./.buildstamp
    echo Product=ISCLOUDER >> ./.buildstamp
    echo Version=$VERSION >> ./.buildstamp
    echo BugURL=http://bugs.centos.org >> ./.buildstamp
    echo IsFinal=True >> ./.buildstamp
    echo UUID=201407041550.x86_64 >> ./.buildstamp
    echo [Compose] >> ./.buildstamp
    echo Lorax=19.6.28-1 >> ./.buildstamp

    find . | cpio -c -o | xz -9 --format=lzma > ../initrd.img
    cd /tmp
    cp initrd.img $TMP_PATH/isolinux/
}

change_pic() {
    cd $MED_PATH
    mkdir $MED_PATH/rootfs
    unsquashfs $SRC_PATH/LiveOS/squashfs.img 
    mount -rw $MED_PATH/squashfs-root/LiveOS/rootfs.img $MED_PATH/rootfs

    #rm $MED_PATH/rootfs/usr/share/anaconda/pixmaps/sidebar-logo.png
    cp $CUR_PATH/res/sidebar-logo.png $MED_PATH/rootfs/usr/share/anaconda/pixmaps/sidebar-logo.png
    rm $MED_PATH/rootfs/usr/share/anaconda/pixmaps/rnotes/en/*.png

    echo [Main] > $MED_PATH/rootfs/.buildstamp
    echo Product=ISCLOUDER >> $MED_PATH/rootfs/.buildstamp
    echo Version=$VERSION >> $MED_PATH/rootfs/.buildstamp
    echo BugURL=http://bugs.centos.org >> $MED_PATH/rootfs/.buildstamp
    echo IsFinal=True >> $MED_PATH/rootfs/.buildstamp
    echo UUID=201407041550.x86_64 >> $MED_PATH/rootfs/.buildstamp
    echo [Compose] >> $MED_PATH/rootfs/.buildstamp
    echo Lorax=19.6.28-1 >> $MED_PATH/rootfs/.buildstamp

    sleep 5
    umount $MED_PATH/rootfs
    mksquashfs $MED_PATH/squashfs-root $MED_PATH/squashfs.img
    cp -fv $MED_PATH/squashfs.img $TMP_PATH/LiveOS/

    sed -i 's/CentOS/ISCLOUDER/' $TMP_PATH/.treeinfo
    cp -fv $CUR_PATH/res/splash.jpg $TMP_PATH/isolinux/
}

# Create iso.
build_iso() {
    echo "Create iso ......"
    cd $ISO_PATH
    rm -f *.iso
    mkisofs -o $ISO_NAME -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -J -v -T $TMP_PATH/
    [ $? -ne 0 ] && exit 1
}

copy_rpms
build_private
create_yum
change_isolinux_cfg
change_initrd
change_pic
build_iso

umount $SRC_PATH; rm -rf $SRC_PATH
rm -rf $MED_PATH
rm -rf $TMP_PATH

