@echo off
set SERVER=YOUR_DOMAIN
set PUBKEY=YOUR_PUBLIC_KEY
set API=http://YOUR_DOMAIN:21121

echo [1/4] Download RustDesk...
powershell -Command "$url = (Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest').assets | Where-Object { $_.name -like '*-x86_64.exe' } | Select-Object -First 1 -ExpandProperty browser_download_url; Invoke-WebRequest -Uri $url -OutFile '%TEMP%\rustdesk.exe' -UseBasicParsing"

echo [2/4] Installazione...
"%TEMP%\rustdesk.exe" --silent-install
timeout /t 5 /nobreak >nul

echo [3/4] Configurazione server...
set CONFIG_DIR=%APPDATA%\RustDesk\config
mkdir "%CONFIG_DIR%" 2>nul
(
echo rendezvous_server = '%SERVER%'
echo nat_type = 1
echo [options]
echo custom-rendezvous-server = '%SERVER%'
echo key = '%PUBKEY%'
echo api-server = '%API%'
echo relay-server = '%SERVER%'
) > "%CONFIG_DIR%\RustDesk.toml"

echo [4/4] Completato! Server: %SERVER%
start "" "%ProgramFiles%\RustDesk\RustDesk.exe" 2>nul
pause
