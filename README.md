# Asterisk 22.9.0 — Prebuilt for aarch64 (Debian 13 Trixie)

Prebuilt Asterisk 22.9.0 binary for **ARM64 / aarch64** devices running **Debian 13 (Trixie)**.  
Tested on **Raspberry Pi 3** (aarch64, kernel 6.12).

## Why this exists

Building Asterisk 22 on a Pi 3 requires two non-obvious fixes:

1. **pjproject endianness bug** — The bundled pjproject fails to detect little-endian on aarch64.  
   Fix: manually set `PJ_IS_LITTLE_ENDIAN 1` in `pjlib/include/pj/config.h` before building.

2. **Low RAM** — Pi 3 has 1GB RAM. Build requires a 2GB swapfile and `-j1` for the pjproject stage,  
   then `-j2` for the main Asterisk build.

## Build flags
./configure --with-pjproject-bundled --with-jansson-bundled --with-libjwt-bundled 
--disable-xmldoc CFLAGS="-O1 -pipe -fno-strict-aliasing -g0"
## Quick install

```bash
sudo bash install.sh
Manual install
# Install runtime dependencies
sudo apt-get install -y \
  libbsd0 libc6 libcap2 libcrypt1 libedit2 \
  libgcc-s1 liblzma5 libmd0 libsqlite3-0 \
  libssl3t64 libstdc++6 libtinfo6 liburiparser1 \
  libuuid1 libxml2 libxslt1.1 libzstd1 zlib1g \
  libsrtp2-1 libspandsp2 libjansson4 libgsm1 \
  libspeex1 libspeexdsp1 libogg0 libvorbis0a

# Extract
sudo tar xzf asterisk-22.9.0-aarch64-debian13.tar.gz -C /
sudo ldconfig
Included modules
Channel: chan_pjsip
PJSIP: res_pjsip, res_pjsip_session, res_pjsip_registrar, res_pjsip_outbound_registration,
res_pjsip_nat, res_pjsip_logger, res_pjsip_transport_websocket
RTP/SRTP: res_rtp_asterisk, res_srtp
Codecs: ulaw, alaw, gsm, opus, g722
Apps: app_dial, app_playback, app_voicemail
Tested hardware
Device
OS
Kernel
Status
Raspberry Pi 3
Debian 13 Trixie
6.12.47 aarch64
✅ Working
License
Asterisk is licensed under GPLv2. See Asterisk project.
