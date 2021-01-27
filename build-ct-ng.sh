#!/bin/sh

MAINBUILDROOTDIR=$(pwd)

if [ "x$ONCI" != "x" ] ; then
    . /etc/profile.d/urusprofile.sh
fi

cd crosstool-ng

if [ ! -e install ] ; then
    echo "building xtool"
    ./bootstrap
    ./configure --prefix=$(pwd)/install
    make -j2
    make install
    echo "xtool installed"
fi

cd install

HOST=""
TARGET=""

if [ "x$1" != "x" ] && [ "x$2" != "x" ] ; then
    HOST=$1
    TARGET=$2
else
    printf "missing arguments!\n"
    printf "\nusage: $0 HOST TARGET\n"
    printf "\texample 1: $0 i686-urus-linux arm-urus\n"
    printf "\texample 2: $0 i686-urus avr\n"
    printf "\texample 3: $0 urus-linux i686-urus\n\n"
    printf "Configurations availables:\n\n"
    CONFIGSAVAIL=$(./bin/ct-ng list-samples | cut -c9- | head -n-4 | tail -n+2 | sed '/,\| /!d')
    cnt=0
    for i in $CONFIGSAVAIL
    do
        cnt=$((cnt+1))
        printf "[%03d] %s\n" $cnt $i
        sleep 0.1
    done
    exit 127
fi

CONFIGS=$(./bin/ct-ng list-samples | cut -c9- | head -n-4 | tail -n+2 | sed '/,\| /!d' | grep -i - -e "^$HOST" | grep -i - -e ",.*$TARGET")

if [ -z "$CONFIGS" ] ; then
    echo "Configuration not found."
fi

PUSHD=$(pwd)
cnt=0
cfgs=""

log_build() {
    echo "[ $(date) ]" " $1: " $2 >> $MAINBUILDROOTDIR/log.txt
}

for cfgs in $CONFIGS
do
    log_build "Building" $CONFIGS
    cd $PUSHD
    cnt=$((cnt+1))
    echo "\n\nCONFIG #$cnt"
    ./bin/ct-ng "$cfgs"
    mv .config .configtmp

if [ "x$ONCI" != "x" ] ; then
    mv .configtmp .configtmpci
    sed -r -e 's:(CT_LOG_ALL=).*:CT_LOG_INFO=y:;' \
    -e 's:(CT_LOG_LEVEL_MAX=).*:CT_LOG_LEVEL_MAX="INFO":;' .configtmpci > .configtmp
fi

    sed -r -e 's:^(CT_WORK_DIR)=.*:\1="\/system/urus/.build":;' \
    -e 's:\$\{CT_LIB_DIR\}.*:\$\{CT_TOP_DIR\}/../../linux\":;' \
    -e 's:(CT_KERNEL_LINUX_CUSTOM_LOCATION=).*:CT_KERNEL_LINUX_CUSTOM_LOCATION=\"\$\{CT_TOP_DIR\}/../../linux\":;' \
    -e 's:(CT_PREFIX_DIR=).*:CT_PREFIX_DIR=\"/system/urus/toolchain/\$\{CT_TARGET\}\":;' \
    -e 's:(CT_RM_RF_PREFIX_DIR=).*::;' \
    -e 's:(CT_PARALLEL_JOBS=).*:CT_PARALLEL_JOBS=6:;' \
    -e 's:(CT_LOAD=).*:CT_LOAD="6":;' \
    -e 's:(#.*CT_STRIP_TARGET_TOOLCHAIN_EXECUTABLES).*:CT_STRIP_TARGET_TOOLCHAIN_EXECUTABLES=y:;' .configtmp > .config

    ./bin/ct-ng build
    cd /system/urus/.build
    STRIP=$(find $(pwd) -executable -name "$TARGET*-strip")
    log_build "Command strip" $STRIP
    printf "\nCurrent folder: %s\n\n" $(pwd)

    cd /system/urus/toolchain
    echo "compressing output toolchain folders"
    TOOLCHAINS=$(find . -maxdepth 1 -type d | tail -n+2 | grep -v ".tar.xz" | grep -v "bak")
    for toolfolder in $TOOLCHAINS
    do
        echo $toolfolder
        PUSHDTOOL=$(pwd)
        TARFILENAME=$(printf "$cfgs" | sed -e 's:,.*::;' | xargs printf "HOST-%s-TGT-$(basename $toolfolder)")
        cntfl=$(find -name "*.tar.xz" | grep -e $TARFILENAME | wc -l)
        cd $toolfolder
        ls ./bin/*ct-ng.config *.log* 2>/dev/null | xargs rm -f
        find . | xargs $STRIP -g -S -d --strip-debug --strip-unneeded 2>/dev/null
        echo "\ntoolchain striped $STRIP"
        printf "\ncompressing current folder $toolfolder\n"
        echo $cfgs | sed -e 's:,.*::;'
        printf "TARFILENAME after: %s\n" $TARFILENAME
        if [ $cntfl -gt 0 ] ; then
            TARFILENAME=$TARFILENAME-$cntfl
        fi
        printf "TARFILENAME before: %s\n" $TARFILENAME
        tar -cJf ../$TARFILENAME.tar.xz *
        cd $PUSHDTOOL
        md5sum $TARFILENAME.tar.xz > $TARFILENAME.tar.xz.md5
        mv $toolfolder $TARFILENAME-bak
    done

    cd /system/urus/.build
    echo "removing temp build folders"
    find . -maxdepth 1 -type d | tail -n+2 | grep -v "tarballs" | xargs rm -rf

    sleep 2
done

exit 0
