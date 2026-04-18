#!/bin/bash
set -e

# Ensure root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
error(){ echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

REPO="RafikBeng/asterisk-22-aarch64-debian13"

# --- 1. FETCH LATEST RELEASE ---
log "Fetching latest release info from GitHub..."
LATEST=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
TAG=$(echo "$LATEST" | grep '"tag_name"' | cut -d'"' -f4)
TAR_URL=$(echo "$LATEST" | grep '"browser_download_url"' | grep -i 'asterisk.*\.tar\.gz' | cut -d'"' -f4)

if [ -z "$TAG" ] || [ -z "$TAR_URL" ]; then
  error "Could not fetch release info from GitHub!"
fi

TAR_FILE=$(basename "$TAR_URL")
log "Latest release: $TAG"
log "Asset: $TAR_FILE"

# --- 2. ASTERISK USER ---
log "Configuring asterisk user..."
getent group asterisk >/dev/null || groupadd asterisk
if ! getent passwd asterisk >/dev/null; then
  useradd -r -d /var/lib/asterisk -s /bin/bash -g asterisk asterisk
fi

# --- 3. DEPENDENCIES ---
log "Installing Asterisk runtime dependencies..."
apt-get update
apt-get install -y \
  libbsd0 libc6 libcap2 libcrypt1 libedit2 \
  libgcc-s1 liblzma5 libmd0 libsqlite3-0 \
  libssl3t64 libstdc++6 libtinfo6 liburiparser1 \
  libuuid1 libxml2 libxslt1.1 libzstd1 zlib1g \
  libsrtp2-1 libspandsp2 libjansson4 libgsm1 \
  libspeex1 libspeexdsp1 libogg0 libvorbis0a

# --- 4. DOWNLOAD ---
log "Downloading Asterisk ${TAG}..."
DOWNLOAD_SUCCESS=0
for attempt in {1..3}; do
  if wget --show-progress -O /tmp/asterisk.tar.gz "$TAR_URL"; then
    if tar -tzf /tmp/asterisk.tar.gz >/dev/null 2>&1; then
      DOWNLOAD_SUCCESS=1
      log "Download verified successfully."
      break
    else
      warn "Downloaded file corrupted. Attempt $attempt/3"
      rm -f /tmp/asterisk.tar.gz
    fi
  else
    warn "Download failed. Attempt $attempt/3"
    rm -f /tmp/asterisk.tar.gz
  fi
  sleep 2
done

[ $DOWNLOAD_SUCCESS -eq 0 ] && error "Failed to download after 3 attempts."

# --- 5. EXTRACT ---
log "Extracting Asterisk files..."
tar -xzf /tmp/asterisk.tar.gz -C /
rm -f /tmp/asterisk.tar.gz

# --- 6. DIRECTORIES & PERMISSIONS ---
log "Creating runtime directories and setting ownership..."
mkdir -p /var/run/asterisk \
         /var/log/asterisk \
         /var/lib/asterisk \
         /var/spool/asterisk \
         /etc/asterisk \
         /usr/lib/asterisk/modules \
         /var/lib/asterisk/agi-bin

chown -R asterisk:asterisk \
  /var/run/asterisk \
  /var/log/asterisk \
  /var/lib/asterisk \
  /var/spool/asterisk \
  /etc/asterisk \
  /usr/lib/asterisk/modules

chown asterisk:asterisk /usr/sbin/asterisk
chmod +x /usr/sbin/asterisk

# --- 7. VALIDATE INSTALLATION ---
log "Validating installation..."
[ ! -x /usr/sbin/asterisk ]          && error "Asterisk binary missing!"
[ ! -d /usr/lib/asterisk/modules ]   && error "Asterisk modules directory missing!"

# --- 8. ASTERISK CONFIG ---
log "Writing asterisk.conf..."
cat > /etc/asterisk/asterisk.conf <<'EOF'
[directories]
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk

[options]
runuser = asterisk
rungroup = asterisk
EOF
chown asterisk:asterisk /etc/asterisk/asterisk.conf

# --- 9. SYSTEMD SERVICE ---
log "Installing systemd service..."
cat > /etc/systemd/system/asterisk.service <<'EOF'
[Unit]
Description=Asterisk PBX
After=network.target

[Service]
Type=simple
User=asterisk
Group=asterisk
ExecStart=/usr/sbin/asterisk -f -C /etc/asterisk/asterisk.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable asterisk

# --- 10. SHARED LIBRARY CACHE ---
log "Updating shared library cache..."
ldconfig

# --- 11. START & HEALTH CHECK ---
log "Starting Asterisk..."
systemctl start asterisk
sleep 5

ASTERISK_READY=0
for i in {1..10}; do
  if asterisk -rx "core show version" &>/dev/null; then
    ASTERISK_READY=1
    log "✓ Asterisk is responding to CLI."
    break
  fi
  warn "Waiting for Asterisk to respond... ($i/10)"
  sleep 3
done

if [ $ASTERISK_READY -eq 0 ]; then
  error "Asterisk failed to respond after startup. Check: journalctl -xeu asterisk"
fi

ASTERISK_VERSION=$(asterisk -rx "core show version" 2>/dev/null | head -n1)

echo ""
echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}     ✅ Asterisk ${TAG} installed successfully!          ${NC}"
echo -e "${GREEN}     ${ASTERISK_VERSION}${NC}"
echo -e "${GREEN}========================================================${NC}"
echo ""
echo "Useful commands:"
echo "  systemctl status asterisk"
echo "  journalctl -xeu asterisk"
echo "  asterisk -r"
