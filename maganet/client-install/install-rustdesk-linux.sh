#!/bin/bash
# MaGa — Installazione RustDesk su Linux

SERVER="betterdesk.maganet.it"
PUBKEY="w647yKhUkY49QHb/UxomU8oq0ZEf+nVF5+TiNlqHQFg="
API="http://betterdesk.maganet.it:21121"

echo "[MaGa] Installazione RustDesk su Linux..."

echo "[1/4] Download ultima versione RustDesk..."
DEB_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
  | grep browser_download_url \
  | grep 'x86_64.deb' \
  | head -1 \
  | cut -d '"' -f 4)
curl -L "$DEB_URL" -o /tmp/rustdesk.deb

echo "[2/4] Installazione pacchetto..."
if command -v apt-get &>/dev/null; then
  apt-get install -y /tmp/rustdesk.deb 2>/dev/null || dpkg -i /tmp/rustdesk.deb
elif command -v dnf &>/dev/null; then
  RPM_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
    | grep browser_download_url \
    | grep 'x86_64.rpm' \
    | head -1 \
    | cut -d '"' -f 4)
  curl -L "$RPM_URL" -o /tmp/rustdesk.rpm
  dnf install -y /tmp/rustdesk.rpm
fi

echo "[3/4] Configurazione server MaGa..."
# Termina rustdesk se in esecuzione (installazione nuova o cambio server)
pkill -x rustdesk 2>/dev/null
sleep 2

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
