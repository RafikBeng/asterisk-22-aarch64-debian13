#!/bin/bash
set -e

# Ensure root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

TAR_FILE="asterisk-22.9.0-arm64-debian13.tar.gz"


if [ ! -f "$TAR_FILE" ]; then
  echo "ERROR: $TAR_FILE not found!"
  exit 1
fi

echo "Installing Asterisk 22.9.0 runtime dependencies..."
apt-get update
apt-get install -y \
  libbsd0 libc6 libcap2 libcrypt1 libedit2 \
  libgcc-s1 liblzma5 libmd0 libsqlite3-0 \
  libssl3t64 libstdc++6 libtinfo6 liburiparser1 \
  libuuid1 libxml2 libxslt1.1 libzstd1 zlib1g \
  libsrtp2-1 libspandsp2 libjansson4 libgsm1 \
  libspeex1 libspeexdsp1 libogg0 libvorbis0a

wget -q https://github.com/RafikBeng/asterisk-22-aarch64-debian13/releases/download/asterisk-22.9.0/asterisk-22.9.0-arm64-debian13.tar.gz
echo "Extracting Asterisk files..."
tar xzf "$TAR_FILE" -C /

echo "Creating runtime directory..."
mkdir -p /var/run/asterisk

echo "Validating installation..."

if [ ! -x /usr/sbin/asterisk ]; then
  echo "ERROR: Asterisk binary missing!"
  exit 1
fi

if [ ! -d /usr/lib/asterisk/modules ]; then
  echo "ERROR: Asterisk modules missing!"
  exit 1
fi

if [ ! -f /etc/asterisk/asterisk.conf ]; then
  echo "WARNING: No config found in /etc/asterisk"
fi

echo "Installing init.d service..."

cat >/etc/init.d/asterisk <<'EOF'
#! /bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
NAME=asterisk
DESC="Asterisk PBX"
DAEMON=/usr/sbin/asterisk
ASTVARRUNDIR=/var/run/asterisk
ASTETCDIR=/etc/asterisk
TRUE=/bin/true

### BEGIN INIT INFO
# Provides:             asterisk
# Required-Start:    $network $syslog $named $local_fs $remote_fs
# Required-Stop:     $network $syslog $named $local_fs $remote_fs
# Default-Start:        2 3 4 5
# Default-Stop:         0 1 6
# Short-Description:    Asterisk PBX
### END INIT INFO

set -e

if ! [ -x $DAEMON ] ; then
        echo "ERROR: $DAEMON not found"
        exit 0
fi

if ! [ -d $ASTETCDIR ] ; then
        echo "ERROR: $ASTETCDIR directory not found"
        exit 0
fi

. /lib/lsb/init-functions

case "$1" in
  start)
        VERSION=`${DAEMON} -rx 'core show version' 2>/dev/null || ${TRUE}`
        if [ "`echo $VERSION | cut -c 1-8`" = "Asterisk" ]; then
                echo "Asterisk already running."
                exit 0
        fi

        log_begin_msg "Starting $DESC: $NAME"
        [ ! -d $ASTVARRUNDIR ] && mkdir -p $ASTVARRUNDIR
        start-stop-daemon --start --oknodo --exec $DAEMON -- -f
        log_end_msg $?
        ;;
  stop)
        log_begin_msg "Stopping $DESC: $NAME"
        start-stop-daemon --stop --oknodo --exec $DAEMON
        log_end_msg $?
        ;;
  reload)
        echo "Reloading $DESC configuration..."
        $DAEMON -rx 'module reload' > /dev/null 2>&1
        ;;
  restart|force-reload)
        $0 stop
        sleep 2
        $0 start
        ;;
  status)
        status_of_proc "$DAEMON" "$NAME"
        exit $?
        ;;
  *)
        echo "Usage: /etc/init.d/asterisk {start|stop|restart|reload|force-reload|status}"
        exit 1
        ;;
esac

exit 0
EOF

chmod +x /etc/init.d/asterisk
update-rc.d asterisk defaults

echo "Updating shared library cache..."
ldconfig

echo ""
echo "✅ Installation complete!"
echo ""
echo "Start service:"
echo "  systemctl start asterisk"
echo ""
echo "Check status:"
echo "  systemctl status asterisk"
