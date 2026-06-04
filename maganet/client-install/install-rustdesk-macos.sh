#!/bin/bash
# MaGa — Installazione RustDesk + BetterDesk Agent su macOS
# Eseguire con: sudo bash install-rustdesk-macos.sh

set -e

SERVER="betterdesk.maganet.it"
PUBKEY="w647yKhUkY49QHb/UxomU8oq0ZEf+nVF5+TiNlqHQFg="
API="http://betterdesk.maganet.it:21121"
PERMANENT_PWD="MaGa2026"

BDAGENT_SERVER="wss://betterdesk.maganet.it/cdap"
BDAGENT_API_KEY="2d9f4cc4edc4f4d4c169b4ea638a4832e2c9b7d387b73e9b10d54cf3faa73fc0"
INSTALL_DIR="/opt/betterdesk-agent"
DATA_DIR="/var/lib/betterdesk-agent"
SERVICE_NAME="it.maganet.betterdesk-agent"
PLIST_PATH="/Library/LaunchDaemons/${SERVICE_NAME}.plist"
ARCH=$(uname -m)

echo "============================================"
echo " [MaGa] Installazione RustDesk + Agente"
echo "============================================"
echo

echo "[1/6] Download ultima versione RustDesk..."
DMG_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
  | grep browser_download_url | grep '.dmg' | head -1 | cut -d '"' -f 4)
curl -L "$DMG_URL" -o /tmp/rustdesk.dmg

echo "[2/6] Installazione RustDesk..."
hdiutil attach /tmp/rustdesk.dmg -quiet
cp -R /Volumes/RustDesk/RustDesk.app /Applications/ 2>/dev/null || true
hdiutil detach /Volumes/RustDesk -quiet 2>/dev/null || true

echo "[3/6] Configurazione server MaGa..."
pkill -x RustDesk 2>/dev/null || true
sleep 2

# Scrive la config in tutti i percorsi possibili
for CONFIG_DIR in \
  "$HOME/.config/rustdesk" \
  "/root/.config/rustdesk" \
  "/Library/Application Support/RustDesk/config"; do
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
mkdir -p "$INSTALL_DIR" "$DATA_DIR"

if [ "$ARCH" = "x86_64" ]; then
  BINARY_NAME="betterdesk-agent-darwin-amd64"
elif [ "$ARCH" = "arm64" ]; then
  BINARY_NAME="betterdesk-agent-darwin-arm64"
else
  echo "Architettura non supportata: $ARCH"
  exit 1
fi

curl -sL "https://github.com/UNITRONIX/BetterDesk/releases/latest/download/${BINARY_NAME}" \
  -o "${INSTALL_DIR}/betterdesk-agent"
chmod +x "${INSTALL_DIR}/betterdesk-agent"

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

echo "[5/6] Creazione e avvio servizio launchd..."
# Rimuovi eventuale servizio precedente
launchctl unload "${PLIST_PATH}" 2>/dev/null || true

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

chown root:wheel "${PLIST_PATH}"
chmod 644 "${PLIST_PATH}"
launchctl load "${PLIST_PATH}"
launchctl start "${SERVICE_NAME}"

echo "[6/6] Avvio RustDesk..."
open /Applications/RustDesk.app 2>/dev/null || true

echo
echo "============================================"
echo " Installazione completata!"
echo " RustDesk : $SERVER"
echo " Agente   : $BDAGENT_SERVER"
echo " Pwd fissa: $PERMANENT_PWD"
echo " Device   : $(hostname)"
echo "============================================"
