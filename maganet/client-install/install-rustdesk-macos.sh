#!/bin/bash
# MaGa — Installazione RustDesk su macOS

SERVER="betterdesk.maganet.it"
PUBKEY="w647yKhUkY49QHb/UxomU8oq0ZEf+nVF5+TiNlqHQFg="
API="http://betterdesk.maganet.it:21121"

echo "[MaGa] Installazione RustDesk su macOS..."

echo "[1/4] Download ultima versione RustDesk..."
DMG_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
  | grep browser_download_url \
  | grep '.dmg' \
  | head -1 \
  | cut -d '"' -f 4)
curl -L "$DMG_URL" -o /tmp/rustdesk.dmg

echo "[2/4] Installazione..."
hdiutil attach /tmp/rustdesk.dmg -quiet
cp -R /Volumes/RustDesk/RustDesk.app /Applications/ 2>/dev/null || true
hdiutil detach /Volumes/RustDesk -quiet 2>/dev/null || true

echo "[3/4] Configurazione server MaGa..."
# Termina RustDesk se in esecuzione (installazione nuova o cambio server)
pkill -x RustDesk 2>/dev/null
sleep 2

# Su macOS i config risiedono in ~/.config/rustdesk (non in Library/Preferences)
CONFIG_DIR="$HOME/.config/rustdesk"
mkdir -p "$CONFIG_DIR"

# RustDesk.toml - configurazione generale
cat > "$CONFIG_DIR/RustDesk.toml" <<EOF
rendezvous_server = '$SERVER'
nat_type = 1
[options]
custom-rendezvous-server = '$SERVER'
key = '$PUBKEY'
api-server = '$API'
relay-server = '$SERVER'
EOF

# RustDesk2.toml - parametri server che prevalgono sul toml principale
cat > "$CONFIG_DIR/RustDesk2.toml" <<EOF
rendezvous_server = '$SERVER'
nat_type = 1
[options]
custom-rendezvous-server = '$SERVER'
key = '$PUBKEY'
api-server = '$API'
relay-server = '$SERVER'
EOF

echo "[4/4] Completato!"
echo "  Server: $SERVER"
echo "  API:    $API"
open /Applications/RustDesk.app 2>/dev/null || true
