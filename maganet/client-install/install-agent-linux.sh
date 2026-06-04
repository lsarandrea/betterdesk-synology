#!/bin/bash
# ============================================================
# BetterDesk Agent — Installazione Linux (systemd)
# Server: betterdesk.maganet.it
# ============================================================
set -e

BDAGENT_VERSION="latest"
BDAGENT_SERVER="wss://betterdesk.maganet.it/cdap"
BDAGENT_API_KEY="2d9f4cc4edc4f4d4c169b4ea638a4832e2c9b7d387b73e9b10d54cf3faa73fc0"
BDAGENT_INSTALL_DIR="/opt/betterdesk-agent"
BDAGENT_DATA_DIR="/var/lib/betterdesk-agent"
SERVICE_NAME="betterdesk-agent"
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
  BINARY_NAME="betterdesk-agent-linux-amd64"
elif [ "$ARCH" = "aarch64" ]; then
  BINARY_NAME="betterdesk-agent-linux-arm64"
else
  echo "Architettura non supportata: $ARCH"
  exit 1
fi

echo "[1/5] Download betterdesk-agent ($ARCH)..."
mkdir -p "$BDAGENT_INSTALL_DIR" "$BDAGENT_DATA_DIR"
curl -sL "https://github.com/UNITRONIX/BetterDesk/releases/latest/download/${BINARY_NAME}" \
  -o "${BDAGENT_INSTALL_DIR}/betterdesk-agent"
chmod +x "${BDAGENT_INSTALL_DIR}/betterdesk-agent"

echo "[2/5] Scrittura configurazione..."
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

echo "[3/5] Creazione servizio systemd..."
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

echo "[4/5] Abilitazione e avvio servizio..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

echo "[5/5] Verifica stato..."
systemctl status ${SERVICE_NAME} --no-pager
echo ""
echo "✅ BetterDesk Agent installato e avviato!"
echo "   Server: ${BDAGENT_SERVER}"
echo "   Device: $(hostname)"
