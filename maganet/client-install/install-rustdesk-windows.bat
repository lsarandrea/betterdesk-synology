@echo off
set SERVER=betterdesk.maganet.it
set PUBKEY=w647yKhUkY49QHb/UxomU8oq0ZEf+nVF5+TiNlqHQFg=
set API=http://betterdesk.maganet.it:21121
set PERMANENT_PWD=MaGa2026
set BDAGENT_SERVER=wss://betterdesk.maganet.it/cdap
set BDAGENT_API_KEY=2d9f4cc4edc4f4d4c169b4ea638a4832e2c9b7d387b73e9b10d54cf3faa73fc0
set BDAGENT_DIR=C:\ProgramData\BetterDesk
set SERVICE_NAME=BetterDeskAgent

echo ============================================
echo  [MaGa] Installazione RustDesk + Agente
echo ============================================
echo.

echo [1/8] Download ultima versione RustDesk...
powershell -Command "$url = (Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest').assets | Where-Object { $_.name -like '*-x86_64.exe' } | Select-Object -First 1 -ExpandProperty browser_download_url; Invoke-WebRequest -Uri $url -OutFile '%TEMP%\rustdesk.exe' -UseBasicParsing"

echo [2/8] Stop servizio e processi RustDesk (incluse precedenti installazioni)...
sc stop RustDesk 2>nul
taskkill /F /IM RustDesk.exe 2>nul
timeout /t 3 /nobreak >nul

echo [3/8] Installazione silenziosa RustDesk...
"%TEMP%\rustdesk.exe" --silent-install
timeout /t 8 /nobreak >nul

echo [4/8] Stop servizio post-installazione...
sc stop RustDesk 2>nul
taskkill /F /IM RustDesk.exe 2>nul
timeout /t 3 /nobreak >nul

echo [5/8] Configurazione server MaGa (tutti i percorsi)...

set CONFIGDIR1=%ProgramData%\RustDesk\config
set CONFIGDIR2=%SystemRoot%\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config
set CONFIGDIR3=%SystemRoot%\System32\config\systemprofile\AppData\Roaming\RustDesk\config
set CONFIGDIR4=%APPDATA%\RustDesk\config

for %%D in ("%CONFIGDIR1%" "%CONFIGDIR2%" "%CONFIGDIR3%" "%CONFIGDIR4%") do (
  mkdir %%D 2>nul
  (
  echo rendezvous_server = '%SERVER%'
  echo nat_type = 1
  echo serial = 0
  echo unlock_pin = ''
  echo [options]
  echo custom-rendezvous-server = '%SERVER%'
  echo key = '%PUBKEY%'
  echo api-server = '%API%'
  echo relay-server = '%SERVER%'
  echo allow-remote-config-modification = 'Y'
  ) > "%%~D\RustDesk2.toml"
  copy "%%~D\RustDesk2.toml" "%%~D\RustDesk.toml" >nul 2>nul
)

rem Imposta password permanente in tutti i percorsi
powershell -NoProfile -Command ^
  "$p='%PERMANENT_PWD%'; $paths=@('%CONFIGDIR1%','%CONFIGDIR2%','%CONFIGDIR3%','%CONFIGDIR4%'); foreach($d in $paths){ $f=Join-Path $d 'RustDesk2.toml'; if(Test-Path $f){ $c=Get-Content $f -Raw; if($c -notmatch 'permanent-password'){ $c=$c.TrimEnd()+\"`npermanent-password = '$p'`n\" }else{ $c=$c -replace \"permanent-password = '.*'\",\"permanent-password = '$p'\" }; Set-Content -Path $f -Value $c -Encoding UTF8; Copy-Item $f (Join-Path $d 'RustDesk.toml') -Force } }"

echo [6/8] Avvio RustDesk con nuova configurazione...
sc start RustDesk 2>nul
timeout /t 3 /nobreak >nul

echo [7/8] Installazione BetterDesk Agent...
mkdir "%BDAGENT_DIR%" 2>nul
mkdir "%BDAGENT_DIR%\data" 2>nul

rem Download NSSM
powershell -Command "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile '%TEMP%\nssm.zip' -UseBasicParsing"
powershell -Command "Expand-Archive -Path '%TEMP%\nssm.zip' -DestinationPath '%TEMP%\nssm' -Force"
powershell -Command "Copy-Item (Get-ChildItem '%TEMP%\nssm' -Recurse -Filter 'nssm.exe' | Where-Object { $_.Directory -match 'win64' } | Select-Object -First 1).FullName -Destination '%BDAGENT_DIR%\nssm.exe'"

rem Download betterdesk-agent.exe
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/UNITRONIX/BetterDesk/releases/latest/download/betterdesk-agent.exe' -OutFile '%BDAGENT_DIR%\betterdesk-agent.exe' -UseBasicParsing"

rem Scrittura config agente
(
echo {
echo   "server": "%BDAGENT_SERVER%",
echo   "auth_method": "api_key",
echo   "api_key": "%BDAGENT_API_KEY%",
echo   "device_name": "%COMPUTERNAME%",
echo   "device_type": "os_agent",
echo   "terminal": true,
echo   "file_browser": true,
echo   "clipboard": true,
echo   "screenshot": true,
echo   "heartbeat_sec": 15,
echo   "log_level": "info",
echo   "data_dir": "%BDAGENT_DIR%\data"
echo }
) > "%BDAGENT_DIR%\config.json"

rem Rimuovi eventuale servizio precedente
sc stop %SERVICE_NAME% 2>nul
"%BDAGENT_DIR%\nssm.exe" remove %SERVICE_NAME% confirm 2>nul

rem Installa e avvia servizio
"%BDAGENT_DIR%\nssm.exe" install %SERVICE_NAME% "%BDAGENT_DIR%\betterdesk-agent.exe" "-config \"%BDAGENT_DIR%\config.json\""
"%BDAGENT_DIR%\nssm.exe" set %SERVICE_NAME% Start SERVICE_AUTO_START
"%BDAGENT_DIR%\nssm.exe" set %SERVICE_NAME% DisplayName "BetterDesk Agent"
sc start %SERVICE_NAME% 2>nul

echo [8/8] Avvio interfaccia RustDesk...
start "" "%ProgramFiles%\RustDesk\RustDesk.exe" 2>nul

echo.
echo ============================================
echo  Installazione completata!
echo  RustDesk  : %SERVER%
echo  Agente    : %BDAGENT_SERVER%
echo  Pwd fissa : %PERMANENT_PWD%
echo  Device    : %COMPUTERNAME%
echo ============================================
echo.
