#!/bin/bash
# ============================================================
# BetterDesk Agent — Installazione macOS (launchd)
# Server: betterdesk.maganet.it
# Eseguire con: sudo bash install-agent-macos.sh
# ============================================================
set -e

BDAGENT_SERVER="wss://betterdesk.maganet.it/cdap"
BDAGENT_API_KEY="2d9f4cc4edc4f4d4c169b4ea638a4832e2c9b7d387b73e9b10d54cf3faa73fc0"
INSTALL_DIR="/opt/betterdesk-agent"
DATA_DIR="/var/lib/betterdesk-agent"
SERVICE_NAME="it.maganet.betterdesk-agent"
PLIST_PATH="/Library/LaunchDaemons/${SERVICE_NAME}.plist"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  BINARY_NAME="betterdesk-agent-darwin-amd64"
elif [ "$ARCH" = "arm64" ]; then
  BINARY_NAME="betterdesk-agent-darwin-arm64"
else
  echo "Architettura non supportata: $ARCH"
  exit 1
fi

echo "[1/5] Download betterdesk-agent ($ARCH)..."
mkdir -p "$INSTALL_DIR" "$DATA_DIR"
curl -sL "https://github.com/UNITRONIX/BetterDesk/releases/latest/download/${BINARY_NAME}" \
  -o "${INSTALL_DIR}/betterdesk-agent"
chmod +x "${INSTALL_DIR}/betterdesk-agent"

echo "[2/5] Scrittura configurazione..."
cat > "${INSTALL_DIR}/config.json" <<EOF
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
  "data_dir": "${DATA_DIR}"
}
EOF

echo "[3/5] Creazione LaunchDaemon plist..."
cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${SERVICE_NAME}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${INSTALL_DIR}/betterdesk-agent</string>
    <string>-config</string>
    <string>${INSTALL_DIR}/config.json</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/var/log/betterdesk-agent.log</string>
  <key>StandardErrorPath</key>
  <string>/var/log/betterdesk-agent.err</string>
</dict>
</plist>
EOF

echo "[4/5] Impostazione permessi plist..."
chown root:wheel "${PLIST_PATH}"
chmod 644 "${PLIST_PATH}"

echo "[5/5] Avvio servizio launchd..."
launchctl load "${PLIST_PATH}"
launchctl start "${SERVICE_NAME}"

echo ""
echo "✅ BetterDesk Agent installato e avviato!"
echo "   Server: ${BDAGENT_SERVER}"
echo "   Device: $(hostname)"
echo "   Log:    /var/log/betterdesk-agent.log"
