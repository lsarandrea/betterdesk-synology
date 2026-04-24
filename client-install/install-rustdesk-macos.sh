#!/bin/bash
set -e

SERVER="YOUR_DOMAIN"
PUBKEY="YOUR_PUBLIC_KEY"
API="http://YOUR_DOMAIN:21121"

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  ARCH_SUFFIX="aarch64"
else
  ARCH_SUFFIX="x86_64"
fi

echo "[1/3] Download RustDesk macOS $ARCH_SUFFIX..."
DMG_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
  | grep browser_download_url | grep "$ARCH_SUFFIX.dmg" | head -1 | cut -d '"' -f 4)

curl -L -o /tmp/rustdesk.dmg "$DMG_URL"

echo "[2/3] Installazione..."
MOUNT_DIR=$(hdiutil attach /tmp/rustdesk.dmg | grep Volumes | awk '{print $3}')
cp -R "$MOUNT_DIR/RustDesk.app" /Applications/
hdiutil detach "$MOUNT_DIR" -quiet
rm -f /tmp/rustdesk.dmg

echo "[3/3] Configurazione server..."
CONFIG_DIR="$HOME/Library/Preferences/RustDesk/config"
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

echo "Completato! Server: $SERVER"
open /Applications/RustDesk.app
