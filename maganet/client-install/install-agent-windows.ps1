# ============================================================
# BetterDesk Agent — Installazione Windows (NSSM service)
# Server: betterdesk.maganet.it
# Eseguire come Amministratore
# ============================================================

$BDAGENT_SERVER   = "wss://betterdesk.maganet.it/cdap"
$BDAGENT_API_KEY  = "2d9f4cc4edc4f4d4c169b4ea638a4832e2c9b7d387b73e9b10d54cf3faa73fc0"
$INSTALL_DIR      = "C:\ProgramData\BetterDesk"
$BINARY_URL       = "https://github.com/UNITRONIX/BetterDesk/releases/latest/download/betterdesk-agent.exe"
$NSSM_URL         = "https://nssm.cc/release/nssm-2.24.zip"
$SERVICE_NAME     = "BetterDeskAgent"

Write-Host "[1/5] Creazione cartella installazione..."
New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null

Write-Host "[2/5] Download betterdesk-agent.exe..."
Invoke-WebRequest -Uri $BINARY_URL -OutFile "$INSTALL_DIR\betterdesk-agent.exe" -UseBasicParsing

Write-Host "[3/5] Scrittura configurazione..."
$config = @{
    server       = $BDAGENT_SERVER
    auth_method  = "api_key"
    api_key      = $BDAGENT_API_KEY
    device_name  = $env:COMPUTERNAME
    device_type  = "os_agent"
    terminal     = $true
    file_browser = $true
    clipboard    = $true
    screenshot   = $true
    heartbeat_sec = 15
    log_level    = "info"
    data_dir     = "$INSTALL_DIR\data"
} | ConvertTo-Json
$config | Out-File -FilePath "$INSTALL_DIR\config.json" -Encoding UTF8

Write-Host "[4/5] Download e installazione NSSM..."
$nssmZip = "$env:TEMP\nssm.zip"
Invoke-WebRequest -Uri $NSSM_URL -OutFile $nssmZip -UseBasicParsing
Expand-Archive -Path $nssmZip -DestinationPath "$env:TEMP\nssm" -Force
$nssmExe = Get-ChildItem -Path "$env:TEMP\nssm" -Recurse -Filter "nssm.exe" | Where-Object { $_.Directory -match 'win64' } | Select-Object -First 1
Copy-Item $nssmExe.FullName -Destination "$INSTALL_DIR\nssm.exe"

Write-Host "[5/5] Registrazione e avvio servizio Windows..."
& "$INSTALL_DIR\nssm.exe" install $SERVICE_NAME "$INSTALL_DIR\betterdesk-agent.exe" "-config `"$INSTALL_DIR\config.json`""
& "$INSTALL_DIR\nssm.exe" set $SERVICE_NAME Start SERVICE_AUTO_START
& "$INSTALL_DIR\nssm.exe" set $SERVICE_NAME DisplayName "BetterDesk Agent"
Start-Service $SERVICE_NAME

Write-Host ""
Write-Host "✅ BetterDesk Agent installato e avviato!"
Write-Host "   Server: $BDAGENT_SERVER"
Write-Host "   Device: $env:COMPUTERNAME"
