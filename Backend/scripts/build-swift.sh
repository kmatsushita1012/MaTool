#!/bin/bash
set -eux

# Install dependencies (no sudo, running as root)
dnf install -y python3-pip git make gcc gcc-c++ cmake clang ninja-build \
  texinfo gmp-devel mpfr-devel libicu-devel libxml2-devel libbsd-devel \
  libuuid-devel libedit-devel sqlite-devel libcurl-devel \
  pkgconfig zlib-devel ncurses-devel tzdata which wget unzip zip tar \
  rsync bison procps-ng swig

# Build ld.gold (optional)
mkdir -p /tmp/ld.gold && cd /tmp/ld.gold
git clone --depth 1 git://sourceware.org/git/binutils-gdb.git binutils
mkdir build && cd build
../binutils/configure --enable-gold --enable-plugins --disable-werror
make all-gold -j$(nproc)
cp gold/ld-new /usr/bin/ld.gold
ld.gold -v
cd /

# Build Swift toolchain
mkdir -p /tmp/swift-project && cd /tmp/swift-project
git clone https://github.com/apple/swift.git
cd swift
./utils/update-checkout --clone

# Set version
SWIFT_VERSION=6.2
./utils/update-checkout --scheme release/$SWIFT_VERSION

# Build (takes a few hours)
./utils/build-script --preset=buildbot_linux,no_assertions,no_test \
  install_destdir=/tmp installable_package=/tmp/swift-${SWIFT_VERSION}-amazonlinux2023.tar.gz
