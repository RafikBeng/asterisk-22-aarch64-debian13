#!/bin/bash
set -e

echo "Installing Asterisk 22.9.0 runtime dependencies..."
apt-get update
apt-get install -y \
  libbsd0 libc6 libcap2 libcrypt1 libedit2 \
  libgcc-s1 liblzma5 libmd0 libsqlite3-0 \
  libssl3t64 libstdc++6 libtinfo6 liburiparser1 \
  libuuid1 libxml2 libxslt1.1 libzstd1 zlib1g \
  libsrtp2-1 libspandsp2 libjansson4 libgsm1 \
  libspeex1 libspeexdsp1 libogg0 libvorbis0a

echo "Extracting Asterisk binaries..."
tar xzf asterisk-22.9.0-aarch64-debian13.tar.gz -C /

echo "Creating asterisk user..."
useradd -r -d /var/lib/asterisk -s /sbin/nologin asterisk 2>/dev/null || true

echo "Setting permissions..."
chown -R asterisk:asterisk /var/lib/asterisk
chown -R asterisk:asterisk /var/spool/asterisk
chown -R asterisk:asterisk /var/log/asterisk

echo "Updating shared library cache..."
ldconfig

echo ""
echo "Done! Generate config files by running:"
echo "  asterisk -c"
echo "Or install sample configs from the source tree with:"
echo "  make samples"
