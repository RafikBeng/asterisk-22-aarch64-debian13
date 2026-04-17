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

# Handle both full version numbers and 'current' aliases
if [[ "$ASTERISK_VER" == "22-current" ]] || [[ "$ASTERISK_VER" == "22-lts" ]]; then
    # Fetch the latest 22.x.x version
    LATEST_VERSION=$(curl -s https://downloads.asterisk.org/pub/telephony/asterisk/ | grep -oP 'asterisk-22\.[0-9]+\.[0-9]+\.tar\.gz' | sort -V | tail -n1 | sed 's/asterisk-\(.*\)\.tar\.gz/\1/')
    if [ -n "$LATEST_VERSION" ]; then
        ASTERISK_VER="$LATEST_VERSION"
        echo ">>> [BUILDER] Latest Asterisk 22 version: $ASTERISK_VER"
    else
        echo ">>> [BUILDER] ERROR: Could not determine latest 22.x version"
        exit 1
    fi
fi

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

# --- 7. EXTRACT VERSION AFTER COMPILATION ---
echo ">>> [BUILDER] Extracting Asterisk version..."

# Method 1: Try to get from asterisk binary (most reliable)
REAL_VERSION=""
if [ -f main/asterisk ]; then
    VERSION_OUTPUT=$(./main/asterisk -V 2>/dev/null || echo "")
    # Extract just the version number (e.g., "Asterisk 22.9.0" -> "22.9.0")
    REAL_VERSION=$(echo "$VERSION_OUTPUT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    echo ">>> Version from binary: $REAL_VERSION"
fi

# Method 2: Try configure.ac or configure
if [ -z "$REAL_VERSION" ]; then
    if [ -f configure.ac ]; then
        REAL_VERSION=$(grep -E 'ASTERISK_VERSION' configure.ac | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        echo ">>> Version from configure.ac: $REAL_VERSION"
    fi
fi

# Method 3: Try Makefile
if [ -z "$REAL_VERSION" ]; then
    if [ -f Makefile ]; then
        REAL_VERSION=$(grep -E '^VERSION=' Makefile | cut -d'=' -f2 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo ">>> Version from Makefile: $REAL_VERSION"
    fi
fi

# Method 4: Try version.h (clean extraction without #define)
if [ -z "$REAL_VERSION" ]; then
    if [ -f include/asterisk/version.h ]; then
        # Clean extraction: get anything that looks like version number
        REAL_VERSION=$(grep -E 'ASTERISK_VERSION' include/asterisk/version.h | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        echo ">>> Version from version.h: $REAL_VERSION"
    fi
fi

# Method 5: Fallback to input version if it's a full version number
if [ -z "$REAL_VERSION" ]; then
    if [[ "$ASTERISK_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        REAL_VERSION="$ASTERISK_VER"
        echo ">>> Using input version as fallback: $REAL_VERSION"
    else
        # Last resort: try to extract from the tarball name we downloaded
        REAL_VERSION=$(echo "$ASTERISK_VER" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        if [ -z "$REAL_VERSION" ]; then
            REAL_VERSION="22.0.0"
            echo ">>> WARNING: Could not detect version, using default: $REAL_VERSION"
        fi
    fi
fi

echo ">>> [BUILDER] Final detected Asterisk version: $REAL_VERSION"
echo "$REAL_VERSION" > /tmp/asterisk_version.txt

# --- 8. INSTALL & PACKAGE ---
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
    echo "$REAL_VERSION" > $BUILD_DIR/staging/VERSION.txt
    echo ">>> Version file created with: $REAL_VERSION"
fi

cd $BUILD_DIR/staging

# Create clean tarball name with proper version
TAR_NAME="asterisk-${REAL_VERSION}-arm64-debian13.tar.gz"
echo ">>> [BUILDER] Creating archive: $TAR_NAME"
tar -czvf "$OUTPUT_DIR/$TAR_NAME" .

# Also save the real version to a file in the output directory for GitHub Actions
echo "$REAL_VERSION" > "$OUTPUT_DIR/asterisk-real-version.txt"

# Verify the tarball was created
if [ -f "$OUTPUT_DIR/$TAR_NAME" ]; then
    TARBALL_SIZE=$(du -h "$OUTPUT_DIR/$TAR_NAME" | cut -f1)
    echo ">>> [BUILDER] SUCCESS! Artifact created: $TAR_NAME (Size: $TARBALL_SIZE)"
else
    echo ">>> [BUILDER] ERROR: Failed to create tarball!"
    exit 1
fi

echo ">>> [BUILDER] Real Asterisk version: $REAL_VERSION"
