#!/bin/bash

# ============================================================================
# AUTOMATED BUILD SCRIPT Native ARM64
# TARGET: Asterisk 22 LTS for Debian 13 (Trixie)
# ============================================================================

# Stop execution on any error
set -e

# --- 1. BOOTSTRAP ---
echo ">>> [BUILDER] Starting NATIVE build process..."
export DEBIAN_FRONTEND=noninteractive

# Determine Output Directory based on environment
if [ -n "$GITHUB_WORKSPACE" ]; then
    OUTPUT_DIR="$GITHUB_WORKSPACE"
    echo ">>> [BUILDER] Detected GitHub Actions Native Environment. Output to: $OUTPUT_DIR"
else
    OUTPUT_DIR="/workspace"
    echo ">>> [BUILDER] Defaulting output to: $OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"

# --- 2. DEPENDENCIES ---
echo ">>> [BUILDER] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    build-essential libc6-dev linux-libc-dev gcc g++ \
    git curl wget subversion pkg-config \
    autoconf automake libtool binutils \
    bison flex xmlstarlet libxml2-utils \
    libncurses5-dev libncursesw5-dev libxml2-dev libsqlite3-dev sqlite3 \
    libssl-dev uuid-dev libjansson-dev libedit-dev libxslt1-dev \
    libicu-dev libsrtp2-dev libopus-dev libvorbis-dev libspeex-dev \
    libspeexdsp-dev libgsm1-dev portaudio19-dev \
    unixodbc unixodbc-dev odbcinst libltdl-dev libsystemd-dev \
    libasound2-dev libjwt-dev liburiparser-dev liblua5.4-dev \
    python3 python3-dev python-is-python3 procps ca-certificates gnupg

# --- 3. DOWNLOAD ---
ASTERISK_VER="$1"
[ -z "$ASTERISK_VER" ] && ASTERISK_VER="22-current"
BUILD_DIR="/usr/src/asterisk_build"

mkdir -p $BUILD_DIR
cd $BUILD_DIR

echo ">>> [BUILDER] Downloading Asterisk $ASTERISK_VER..."
wget -qO asterisk.tar.gz "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VER}.tar.gz"
tar -xzf asterisk.tar.gz --strip-components=1
rm asterisk.tar.gz

echo ">>> [BUILDER] Downloading MP3 sources..."
contrib/scripts/get_mp3_source.sh

# --- 4. CONFIGURE ---
echo ">>> [BUILDER] Configuring..."
./configure --libdir=/usr/lib \
    --with-pjproject-bundled \
    --with-jansson-bundled \
    --without-x11 \
    --without-gtk2

# Extract actual Asterisk version from multiple sources
REAL_VERSION=""

# Method 1: Try to get from configure output
if [ -f config.log ]; then
    REAL_VERSION=$(grep 'PACKAGE_VERSION' config.log | head -n1 | cut -d"'" -f2 2>/dev/null || echo "")
fi

# Method 2: Try to get from main/version.c if available
if [ -z "$REAL_VERSION" ] && [ -f main/version.c ]; then
    REAL_VERSION=$(grep -oP 'ASTERISK_VERSION\s+"\K[^"]+' main/version.c 2>/dev/null || echo "")
fi

# Method 3: Try to get from include/asterisk/version.h
if [ -z "$REAL_VERSION" ] && [ -f include/asterisk/version.h ]; then
    REAL_VERSION=$(grep -oP 'ASTERISK_VERSION\s+\K[0-9.]+' include/asterisk/version.h 2>/dev/null || echo "")
fi

# Method 4: Fallback to extracted version from tarball name if input was a specific version
if [ -z "$REAL_VERSION" ]; then
    if [[ "$ASTERISK_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        REAL_VERSION="$ASTERISK_VER"
        echo ">>> [BUILDER] Using input version as fallback: $REAL_VERSION"
    else
        REAL_VERSION="unknown"
    fi
fi

echo ">>> [BUILDER] Detected Asterisk version: $REAL_VERSION"
echo "$REAL_VERSION" > /tmp/asterisk_version.txt

# --- 5. CLEAN & SELECT ---
make -C third-party/pjproject clean || true

make menuselect.makeopts
menuselect/menuselect --enable format_mp3 menuselect.makeopts
menuselect/menuselect --enable CORE-SOUNDS-EN-WAV menuselect.makeopts
menuselect/menuselect --enable CORE-SOUNDS-EN-ULAW menuselect.makeopts
menuselect/menuselect --enable CORE-SOUNDS-EN-ALAW menuselect.makeopts
menuselect/menuselect --enable CORE-SOUNDS-EN-GSM menuselect.makeopts
# BUILD_NATIVE is disabled to avoid optimizing for the specific CPU used by Github Workflows.
menuselect/menuselect --disable BUILD_NATIVE menuselect.makeopts

# --- 6. COMPILE ---
echo ">>> [BUILDER] Compiling (Native Speed)..."
make -j$(nproc)

# --- 7. INSTALL & PACKAGE ---
echo ">>> [BUILDER] Packaging..."
make install DESTDIR=$BUILD_DIR/staging
make samples DESTDIR=$BUILD_DIR/staging

mkdir -p "$BUILD_DIR/staging/etc/init.d"
mkdir -p "$BUILD_DIR/staging/etc/default"
mkdir -p "$BUILD_DIR/staging/usr/lib/systemd/system"

make config DESTDIR=$BUILD_DIR/staging

# Include version file in the tarball
if [ -f /tmp/asterisk_version.txt ]; then
    REAL_VERSION=$(cat /tmp/asterisk_version.txt)
    cp /tmp/asterisk_version.txt $BUILD_DIR/staging/VERSION.txt
fi

cd $BUILD_DIR/staging

# Use the actual detected version for the tarball name if available
if [ "$REAL_VERSION" != "unknown" ] && [ -n "$REAL_VERSION" ]; then
    TAR_NAME="asterisk-${REAL_VERSION}-arm64-debian13.tar.gz"
    echo ">>> [BUILDER] Using detected version for tarball: $REAL_VERSION"
else
    TAR_NAME="asterisk-${ASTERISK_VER}-arm64-debian13.tar.gz"
    echo ">>> [BUILDER] Using input version for tarball: $ASTERISK_VER"
fi

echo ">>> [BUILDER] Creating archive at $OUTPUT_DIR/$TAR_NAME..."
tar -czvf "$OUTPUT_DIR/$TAR_NAME" .

# Also save the real version to a file in the output directory for GitHub Actions
echo "$REAL_VERSION" > "$OUTPUT_DIR/asterisk-real-version.txt"

echo ">>> [BUILDER] SUCCESS! Artifact ready: $TAR_NAME"
echo ">>> [BUILDER] Real Asterisk version: $REAL_VERSION"
