@echo off
setlocal EnableDelayedExpansion
set SERVER=betterdesk.maganet.it
set PUBKEY=w647yKhUkY49QHb/UxomU8oq0ZEf+nVF5+TiNlqHQFg=
set API=http://betterdesk.maganet.it:21121
set PERMANENT_PWD=MaGa2026
set BDAGENT_SERVER=wss://betterdesk.maganet.it/cdap
set BDAGENT_API_KEY=2d9f4cc4edc4f4d4c169b4ea638a4832e2c9b7d387b73e9b10d54cf3faa73fc0
set BDAGENT_DIR=C:\ProgramData\BetterDesk
set SERVICE_NAME=BetterDeskAgent
set LOGFILE=C:\maga-install.log

echo [MaGa] Installazione avviata %DATE% %TIME% > "%LOGFILE%"
echo LOGFILE fisso: %LOGFILE%
echo.

echo ============================================
echo  [MaGa] Installazione RustDesk + Agente
echo ============================================
echo.

echo [1/9] Download ultima versione RustDesk... >> "%LOGFILE%"
echo [1/9] Download ultima versione RustDesk...
powershell -Command "$url = (Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest').assets | Where-Object { $_.name -like '*-x86_64.exe' } | Select-Object -First 1 -ExpandProperty browser_download_url; Invoke-WebRequest -Uri $url -OutFile 'C:\rustdesk-setup.exe' -UseBasicParsing" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE download RustDesk >> "%LOGFILE%" & goto :error )
echo   OK download RustDesk >> "%LOGFILE%"

echo [2/9] Stop aggressivo + rimozione servizio RustDesk esistente... >> "%LOGFILE%"
echo [2/9] Stop aggressivo + rimozione servizio RustDesk esistente...
sc stop RustDesk >> "%LOGFILE%" 2>&1
sc stop "RustDesk" >> "%LOGFILE%" 2>&1
taskkill /F /IM RustDesk.exe >> "%LOGFILE%" 2>&1
taskkill /F /IM rustdesk.exe >> "%LOGFILE%" 2>&1
powershell -Command "Get-Process -Name '*rustdesk*' -ErrorAction SilentlyContinue | Stop-Process -Force" >> "%LOGFILE%" 2>&1
timeout /t 5 /nobreak >nul

REM — RIMOZIONE FORZATA config precedente (cuore del fix problema 1)
echo   Rimozione configurazione precedente RustDesk... >> "%LOGFILE%"
for %%D in (
  "C:\ProgramData\RustDesk\config"
  "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config"
  "C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\config"
  "C:\Users\Public\RustDesk\config"
) do (
  if exist "%%~D\RustDesk.toml"  del /F /Q "%%~D\RustDesk.toml"  >> "%LOGFILE%" 2>&1
  if exist "%%~D\RustDesk2.toml" del /F /Q "%%~D\RustDesk2.toml" >> "%LOGFILE%" 2>&1
  echo   Pulito: %%~D >> "%LOGFILE%"
)
echo   Config precedente rimossa >> "%LOGFILE%"

echo [3/9] Installazione silenziosa RustDesk... >> "%LOGFILE%"
echo [3/9] Installazione silenziosa RustDesk...
"C:\rustdesk-setup.exe" --silent-install
REM — Attesa estesa: il servizio RustDesk si avvia e tenta di creare i .toml
timeout /t 15 /nobreak >nul
echo   OK installazione RustDesk >> "%LOGFILE%"

echo [4/9] Stop post-installazione (prima di scrivere config)... >> "%LOGFILE%"
echo [4/9] Stop post-installazione...
sc stop RustDesk >> "%LOGFILE%" 2>&1
taskkill /F /IM RustDesk.exe >> "%LOGFILE%" 2>&1
taskkill /F /IM rustdesk.exe >> "%LOGFILE%" 2>&1
powershell -Command "Get-Process -Name '*rustdesk*' -ErrorAction SilentlyContinue | Stop-Process -Force" >> "%LOGFILE%" 2>&1
timeout /t 5 /nobreak >nul

echo [5/9] Configurazione server MaGa (tutti i percorsi)... >> "%LOGFILE%"
echo [5/9] Configurazione server MaGa...

set CONFIGDIR1=C:\ProgramData\RustDesk\config
set CONFIGDIR2=C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config
set CONFIGDIR3=C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\config
set CONFIGDIR4=C:\Users\Public\RustDesk\config

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
  echo permanent-password = '%PERMANENT_PWD%'
  echo allow-remote-config-modification = 'Y'
  ) > "%%~D\RustDesk2.toml"
  copy "%%~D\RustDesk2.toml" "%%~D\RustDesk.toml" >nul 2>nul
  echo   Scritto: %%~D >> "%LOGFILE%"
)

echo [6/9] Avvio RustDesk con nuova configurazione... >> "%LOGFILE%"
echo [6/9] Avvio RustDesk...
sc start RustDesk >> "%LOGFILE%" 2>&1
timeout /t 3 /nobreak >nul
sc query RustDesk >> "%LOGFILE%" 2>&1

echo [7/9] Installazione BetterDesk Agent... >> "%LOGFILE%"
echo [7/9] Installazione BetterDesk Agent...

mkdir "%BDAGENT_DIR%" 2>nul
mkdir "%BDAGENT_DIR%\data" 2>nul

echo   Download NSSM... >> "%LOGFILE%"
powershell -Command "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile 'C:\nssm.zip' -UseBasicParsing" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE download NSSM >> "%LOGFILE%" & goto :error )

echo   Estrazione NSSM... >> "%LOGFILE%"
powershell -Command "Expand-Archive -Path 'C:\nssm.zip' -DestinationPath 'C:\nssm-extracted' -Force" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE estrazione NSSM >> "%LOGFILE%" & goto :error )

echo   Copia nssm.exe... >> "%LOGFILE%"
powershell -Command "$f=Get-ChildItem 'C:\nssm-extracted' -Recurse -Filter 'nssm.exe' | Where-Object { $_.Directory -match 'win64' } | Select-Object -First 1; if($f){ Copy-Item $f.FullName '%BDAGENT_DIR%\nssm.exe'; Write-Host 'nssm.exe copiato da: ' $f.FullName } else { Write-Host 'ERRORE: nssm.exe win64 non trovato'; exit 1 }" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE copia nssm.exe >> "%LOGFILE%" & goto :error )

echo   Download betterdesk-agent.exe... >> "%LOGFILE%"
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/UNITRONIX/BetterDesk/releases/latest/download/betterdesk-agent.exe' -OutFile '%BDAGENT_DIR%\betterdesk-agent.exe' -UseBasicParsing" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE download betterdesk-agent.exe >> "%LOGFILE%" & goto :error )
echo   OK download agente >> "%LOGFILE%"

echo [8/9] Scrittura config agente + installazione servizio... >> "%LOGFILE%"
echo [8/9] Scrittura config agente + installazione servizio...

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
echo   Config agente scritta >> "%LOGFILE%"
type "%BDAGENT_DIR%\config.json" >> "%LOGFILE%"

REM — Rimozione servizio agente precedente (se esiste)
sc stop %SERVICE_NAME% >> "%LOGFILE%" 2>&1
"%BDAGENT_DIR%\nssm.exe" remove %SERVICE_NAME% confirm >> "%LOGFILE%" 2>&1

echo   Installazione servizio NSSM... >> "%LOGFILE%"
"%BDAGENT_DIR%\nssm.exe" install %SERVICE_NAME% "%BDAGENT_DIR%\betterdesk-agent.exe" "-config \"%BDAGENT_DIR%\config.json\"" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE install servizio NSSM >> "%LOGFILE%" & goto :error )

"%BDAGENT_DIR%\nssm.exe" set %SERVICE_NAME% Start SERVICE_AUTO_START >> "%LOGFILE%" 2>&1
"%BDAGENT_DIR%\nssm.exe" set %SERVICE_NAME% DisplayName "BetterDesk Agent" >> "%LOGFILE%" 2>&1

sc start %SERVICE_NAME% >> "%LOGFILE%" 2>&1
timeout /t 3 /nobreak >nul
sc query %SERVICE_NAME% >> "%LOGFILE%" 2>&1

echo [9/9] Avvio interfaccia RustDesk...
start "" "%ProgramFiles%\RustDesk\RustDesk.exe" 2>nul

echo.
echo ============================================
echo  Installazione completata!
echo  RustDesk  : %SERVER%
echo  Agente    : %BDAGENT_SERVER%
echo  Pwd fissa : %PERMANENT_PWD%
echo  Device    : %COMPUTERNAME%
echo  Log       : %LOGFILE%
echo ============================================
echo [MaGa] Installazione completata con successo %DATE% %TIME% >> "%LOGFILE%"
goto :end

:error
echo.
echo ============================================
echo  ERRORE! Leggi il log:
echo  %LOGFILE%
echo ============================================
echo [MaGa] Installazione FALLITA %DATE% %TIME% >> "%LOGFILE%"
pause

:end
