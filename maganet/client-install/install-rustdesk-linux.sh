#!/bin/bash
# MaGa — Installazione RustDesk + BetterDesk Agent su Linux
# Eseguire come root: sudo bash install-rustdesk-linux.sh

set -e

SERVER="betterdesk.maganet.it"
PUBKEY="w647yKhUkY49QHb/UxomU8oq0ZEf+nVF5+TiNlqHQFg="
API="http://betterdesk.maganet.it:21121"
PERMANENT_PWD="MaGa2026"

BDAGENT_SERVER="wss://betterdesk.maganet.it/cdap"
BDAGENT_API_KEY="2d9f4cc4edc4f4d4c169b4ea638a4832e2c9b7d387b73e9b10d54cf3faa73fc0"
BDAGENT_INSTALL_DIR="/opt/betterdesk-agent"
BDAGENT_DATA_DIR="/var/lib/betterdesk-agent"
SERVICE_NAME="betterdesk-agent"
ARCH=$(uname -m)

echo "============================================"
echo " [MaGa] Installazione RustDesk + Agente"
echo "============================================"
echo

echo "[1/6] Download ultima versione RustDesk..."
if [ "$ARCH" = "x86_64" ]; then
  DEB_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
    | grep browser_download_url | grep 'x86_64.deb' | head -1 | cut -d '"' -f 4)
  curl -L "$DEB_URL" -o /tmp/rustdesk.deb
elif [ "$ARCH" = "aarch64" ]; then
  DEB_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
    | grep browser_download_url | grep 'aarch64.deb' | head -1 | cut -d '"' -f 4)
  curl -L "$DEB_URL" -o /tmp/rustdesk.deb
fi

echo "[2/6] Installazione RustDesk..."
if command -v apt-get &>/dev/null; then
  apt-get install -y /tmp/rustdesk.deb 2>/dev/null || dpkg -i /tmp/rustdesk.deb
elif command -v dnf &>/dev/null; then
  RPM_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
    | grep browser_download_url | grep 'x86_64.rpm' | head -1 | cut -d '"' -f 4)
  curl -L "$RPM_URL" -o /tmp/rustdesk.rpm
  dnf install -y /tmp/rustdesk.rpm
fi

echo "[3/6] Configurazione server MaGa..."
pkill -x rustdesk 2>/dev/null || true
sleep 2

# Scrive la config in tutti i percorsi possibili
for CONFIG_DIR in \
  "$HOME/.config/rustdesk" \
  "/root/.config/rustdesk" \
  "/etc/rustdesk"; do
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/RustDesk2.toml" <<EOF
rendezvous_server = '$SERVER'
nat_type = 1
serial = 0
[options]
custom-rendezvous-server = '$SERVER'
key = '$PUBKEY'
api-server = '$API'
relay-server = '$SERVER'
permanent-password = '$PERMANENT_PWD'
allow-remote-config-modification = 'Y'
EOF
  cp "$CONFIG_DIR/RustDesk2.toml" "$CONFIG_DIR/RustDesk.toml"
done

echo "[4/6] Installazione BetterDesk Agent..."
mkdir -p "$BDAGENT_INSTALL_DIR" "$BDAGENT_DATA_DIR"

if [ "$ARCH" = "x86_64" ]; then
  BINARY_NAME="betterdesk-agent-linux-amd64"
elif [ "$ARCH" = "aarch64" ]; then
  BINARY_NAME="betterdesk-agent-linux-arm64"
else
  echo "Architettura non supportata: $ARCH"
  exit 1
fi

curl -sL "https://github.com/UNITRONIX/BetterDesk/releases/latest/download/${BINARY_NAME}" \
  -o "${BDAGENT_INSTALL_DIR}/betterdesk-agent"
chmod +x "${BDAGENT_INSTALL_DIR}/betterdesk-agent"

cat > "${BDAGENT_INSTALL_DIR}/config.json" <<EOF
{
  "server": "${BDAGENT_SERVER}",
  "auth_method": "api_key",
  "api_key": "${BDAGENT_API_KEY}",
  "device_name": "$(hostname)",
  "device_type": "os_agent",
  "terminal": true,
  "file_browser": true,
  "clipboard": true,
  "screenshot": true,
  "heartbeat_sec": 15,
  "log_level": "info",
  "data_dir": "${BDAGENT_DATA_DIR}"
}
EOF

echo "[5/6] Creazione e avvio servizio systemd..."
# Rimuovi eventuale servizio precedente
systemctl stop ${SERVICE_NAME} 2>/dev/null || true

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=BetterDesk Agent
After=network.target

[Service]
Type=simple
ExecStart=${BDAGENT_INSTALL_DIR}/betterdesk-agent -config ${BDAGENT_INSTALL_DIR}/config.json
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

echo "[6/6] Completato!"
echo
echo "============================================"
echo " Installazione completata!"
echo " RustDesk : $SERVER"
echo " Agente   : $BDAGENT_SERVER"
echo " Pwd fissa: $PERMANENT_PWD"
echo " Device   : $(hostname)"
echo "============================================"
