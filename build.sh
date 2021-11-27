#!/bin/sh

set -eux

prepareSystem() {
    if type apt-get > /dev/null 2>&1 ; then
        if ! type sudo > /dev/null 2>&1 ; then
            apt-get install sudo || return 1
        fi
        sudo apt-get install build-essential || return 1
    elif type yum > /dev/null 2>&1 ; then
        if ! type sudo > /dev/null 2>&1 ; then
            yum -y install sudo || return 1
        fi
        sudo yum -y groupinstall "Development tools" || return 1
        sudo yum -y install git libstdc++-static glibc-static || return 1
        sudo yum -y install java-1.7.0-openjdk-devel || return 1
        export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk
    fi
}

cloneRepos() {
    git clone "https://github.com/PhoneJ2ME/preverifier.git" || return 1
    git clone "https://github.com/PhoneJ2ME/pcsl.git" || return 1
    git clone "https://github.com/PhoneJ2ME/cldc.git" || return 1
    git clone "https://github.com/PhoneJ2ME/tools.git" || return 1
    git clone "https://github.com/PhoneJ2ME/midp.git" || return 1
}

buildPreverifier() (
    export CFLAGS="-D_FILE_OFFSET_BITS=64"
    cd preverifier/build/linux || return 1
    # checkout to previous commit as latest commit breaks midp buid...
    git checkout 56b1e423d67956d8e21be1d9ccb1c7982fa20bb0 || return 1
    sed -i 's/CFLAGS = /CFLAGS += /g' Makefile || return 1
    make || return 1
)

buildPcsl() (
    export CFLAGS="-D_FILE_OFFSET_BITS=64"
    export NETWORK_MODULE=bsd/generic
    export PCSL_PLATFORM=linux_i386_gcc
    export JDK_DIR="${JAVA_HOME}"
    cd pcsl || return 1
    make || return 1
)

buildCldc() (
    export JVMWORKSPACE="$( pwd )/cldc"
    export PCSL_OUTPUT_DIR="$( pwd )/pcsl/output"
    export JDK_DIR="${JAVA_HOME}"
    export CPP_DEF_FLAGS="-D_FILE_OFFSET_BITS=64"
    export ENABLE_PCSL=true
    export ENABLE_ISOLATES=true
    export ENABLE_COMPILATION_WARNINGS=true
    # export VERBOSE_BUILD=1
    cp preverifier/build/linux/preverify cldc/build/share/bin/linux_i386/preverify || return 1
    sed -i 's/.arch i486/.arch i586/g' cldc/src/vm/cpu/c/AsmStubs_i386.s || return 1
    sed -i 's/.arch i486/.arch i586/g' cldc/src/vm/cpu/i386/SourceAssembler_i386.cpp || return 1
    cd cldc/build/linux_i386 || return 1
    make || return 1
    ls -la dist || return 1
)

buildMidp() (
    export PCSL_OUTPUT_DIR="$( pwd )/pcsl/output"
    export CLDC_DIST_DIR="$( pwd )/cldc/build/linux_i386/dist"
    export TOOLS_DIR="$( pwd )/tools"
    export JDK_DIR="${JAVA_HOME}"
    export CFLAGS="-D_FILE_OFFSET_BITS=64"
    sed -i 's/LD_END_GROUP [?]= --end-group/LD_END_GROUP ?= -Xlinker --end-group/g' midp/build/common/makefiles/gcc.gmk
    sed -i 's/EXTRA_CFLAGS[[:space:]]*[+]=[[:space:]]*-Werror/# EXTRA_CFLAGS += -Werror/g' midp/build/common/makefiles/gcc.gmk
    cd midp/build/linux_fb_gcc || return 1
    make || return 1
    ls -la output || return 1
)

prepareArchives() {
    mkdir archives || return 1
    tar -C cldc/build/linux_i386 -cJf archives/cldc-linux-i386.tar.xz dist || return 1
    tar -C midp/build/linux_fb_gcc -cJf archives/midp-linux-fb-i386.tar.xz output || return 1
    ls -la archives || return 1
}

buildAll() {
    prepareSystem || return 1
    cloneRepos || return 1
    buildPreverifier || return 1
    buildPcsl || return 1
    buildCldc || return 1
    buildMidp || return 1
    prepareArchives || return 1
}

buildAll
