#!/bin/bash
set -e

SERVER="YOUR_DOMAIN"
PUBKEY="YOUR_PUBLIC_KEY"
API="http://YOUR_DOMAIN:21121"

if [ "$EUID" -ne 0 ]; then
  echo "ERRORE: Esegui come root: sudo $0"
  exit 1
fi

ARCH=$(uname -m)
case $ARCH in
  x86_64)  PKG_ARCH="x86_64" ;;
  aarch64) PKG_ARCH="aarch64" ;;
  *) echo "Architettura non supportata: $ARCH"; exit 1 ;;
esac

if command -v apt-get &>/dev/null; then
  PKG_TYPE="deb"
elif command -v dnf &>/dev/null; then
  PKG_TYPE="rpm"
else
  echo "Package manager non supportato"
  exit 1
fi

Add install-rustdesk-linux.sh - script Linux con placeholderDL_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
  | grep browser_download_url | grep "$PKG_ARCH.$PKG_TYPE" | head -1 | cut -d '"' -f 4)

curl -L -o /tmp/rustdesk.$PKG_TYPE "$DL_URL"

echo "[2/3] Installazione..."
if [ "$PKG_TYPE" = "deb" ]; then
  apt-get install -y /tmp/rustdesk.$PKG_TYPE || dpkg -i /tmp/rustdesk.$PKG_TYPE
else
  dnf install -y /tmp/rustdesk.$PKG_TYPE || rpm -ivh /tmp/rustdesk.$PKG_TYPE
fi
rm -f /tmp/rustdesk.$PKG_TYPE

echo "[3/3] Configurazione server..."
CONFIG_DIR="/root/.config/rustdesk/config"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/RustDesk.toml" <<EOF
rendezvous_server = '$SERVER'
nat_type = 1
[options]
custom-rendezvous-server = '$SERVER'
key = '$PUBKEY'
api-server = '$API'
relay-server = '$SERVER'
EOF

if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  USER_CONFIG="$USER_HOME/.config/rustdesk/config"
  mkdir -p "$USER_CONFIG"
  cp "$CONFIG_DIR/RustDesk.toml" "$USER_CONFIG/RustDesk.toml"
  chown -R "$SUDO_USER:$SUDO_USER" "$USER_CONFIG"
fi

echo "Completato! Server: $SERVER"
