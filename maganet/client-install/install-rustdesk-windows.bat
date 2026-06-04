@echo off
set SERVER=betterdesk.maganet.it
set PUBKEY=w647yKhUkY49QHb/UxomU8oq0ZEf+nVF5+TiNlqHQFg=
set API=http://betterdesk.maganet.it:21121
set PERMANENT_PWD=MaGa2026
set BDAGENT_SERVER=wss://betterdesk.maganet.it/cdap
set BDAGENT_API_KEY=2d9f4cc4edc4f4d4c169b4ea638a4832e2c9b7d387b73e9b10d54cf3faa73fc0
set BDAGENT_DIR=C:\ProgramData\BetterDesk
set SERVICE_NAME=BetterDeskAgent
set LOGFILE=%TEMP%\maga-install.log

rem Inizializza log
echo [MaGa] Installazione avviata %DATE% %TIME% > "%LOGFILE%"
echo LOGFILE: %LOGFILE%

echo ============================================
echo  [MaGa] Installazione RustDesk + Agente
echo ============================================
echo.

echo [1/8] Download ultima versione RustDesk... >> "%LOGFILE%"
echo [1/8] Download ultima versione RustDesk...
powershell -Command "$url = (Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest').assets | Where-Object { $_.name -like '*-x86_64.exe' } | Select-Object -First 1 -ExpandProperty browser_download_url; Invoke-WebRequest -Uri $url -OutFile '%TEMP%\rustdesk.exe' -UseBasicParsing" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE download RustDesk >> "%LOGFILE%" & goto :error )

echo [2/8] Stop servizio RustDesk... >> "%LOGFILE%"
echo [2/8] Stop servizio e processi RustDesk...
sc stop RustDesk >> "%LOGFILE%" 2>&1
taskkill /F /IM RustDesk.exe >> "%LOGFILE%" 2>&1
timeout /t 3 /nobreak >nul

echo [3/8] Installazione silenziosa RustDesk... >> "%LOGFILE%"
echo [3/8] Installazione silenziosa RustDesk...
"%TEMP%\rustdesk.exe" --silent-install >> "%LOGFILE%" 2>&1
timeout /t 8 /nobreak >nul

echo [4/8] Stop post-installazione... >> "%LOGFILE%"
echo [4/8] Stop servizio post-installazione...
sc stop RustDesk >> "%LOGFILE%" 2>&1
taskkill /F /IM RustDesk.exe >> "%LOGFILE%" 2>&1
timeout /t 3 /nobreak >nul

echo [5/8] Configurazione server MaGa... >> "%LOGFILE%"
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
  echo   Scritto: %%~D >> "%LOGFILE%"
)

powershell -NoProfile -Command ^
  "$p='%PERMANENT_PWD%'; $paths=@('%CONFIGDIR1%','%CONFIGDIR2%','%CONFIGDIR3%','%CONFIGDIR4%'); foreach($d in $paths){ $f=Join-Path $d 'RustDesk2.toml'; if(Test-Path $f){ $c=Get-Content $f -Raw; if($c -notmatch 'permanent-password'){ $c=$c.TrimEnd()+\"`npermanent-password = '$p'`n\" }else{ $c=$c -replace \"permanent-password = '.*'\",\"permanent-password = '$p'\" }; Set-Content -Path $f -Value $c -Encoding UTF8; Copy-Item $f (Join-Path $d 'RustDesk.toml') -Force } }" >> "%LOGFILE%" 2>&1

echo [6/8] Avvio RustDesk... >> "%LOGFILE%"
echo [6/8] Avvio RustDesk con nuova configurazione...
sc start RustDesk >> "%LOGFILE%" 2>&1
timeout /t 3 /nobreak >nul

echo [7/8] Installazione BetterDesk Agent... >> "%LOGFILE%"
echo [7/8] Installazione BetterDesk Agent...

mkdir "%BDAGENT_DIR%" 2>nul
mkdir "%BDAGENT_DIR%\data" 2>nul

echo   Download NSSM... >> "%LOGFILE%"
powershell -Command "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile '%TEMP%\nssm.zip' -UseBasicParsing" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE download NSSM >> "%LOGFILE%" & goto :error )

echo   Estrazione NSSM... >> "%LOGFILE%"
powershell -Command "Expand-Archive -Path '%TEMP%\nssm.zip' -DestinationPath '%TEMP%\nssm' -Force" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE estrazione NSSM >> "%LOGFILE%" & goto :error )

echo   Copia nssm.exe... >> "%LOGFILE%"
powershell -Command "$f=Get-ChildItem '%TEMP%\nssm' -Recurse -Filter 'nssm.exe' | Where-Object { $_.Directory -match 'win64' } | Select-Object -First 1; if($f){ Copy-Item $f.FullName '%BDAGENT_DIR%\nssm.exe' } else { exit 1 }" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE copia nssm.exe - win64 non trovato >> "%LOGFILE%" & goto :error )

echo   Download betterdesk-agent.exe... >> "%LOGFILE%"
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/UNITRONIX/BetterDesk/releases/latest/download/betterdesk-agent.exe' -OutFile '%BDAGENT_DIR%\betterdesk-agent.exe' -UseBasicParsing" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE download betterdesk-agent.exe >> "%LOGFILE%" & goto :error )

echo   Scrittura config agente... >> "%LOGFILE%"
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
echo   Config agente: >> "%LOGFILE%"
type "%BDAGENT_DIR%\config.json" >> "%LOGFILE%"

echo   Rimozione servizio precedente... >> "%LOGFILE%"
sc stop %SERVICE_NAME% >> "%LOGFILE%" 2>&1
"%BDAGENT_DIR%\nssm.exe" remove %SERVICE_NAME% confirm >> "%LOGFILE%" 2>&1

echo   Installazione servizio... >> "%LOGFILE%"
"%BDAGENT_DIR%\nssm.exe" install %SERVICE_NAME% "%BDAGENT_DIR%\betterdesk-agent.exe" "-config \"%BDAGENT_DIR%\config.json\"" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE install servizio NSSM >> "%LOGFILE%" & goto :error )

"%BDAGENT_DIR%\nssm.exe" set %SERVICE_NAME% Start SERVICE_AUTO_START >> "%LOGFILE%" 2>&1
"%BDAGENT_DIR%\nssm.exe" set %SERVICE_NAME% DisplayName "BetterDesk Agent" >> "%LOGFILE%" 2>&1

echo   Avvio servizio... >> "%LOGFILE%"
sc start %SERVICE_NAME% >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE avvio servizio %SERVICE_NAME% >> "%LOGFILE%" & goto :error )

echo [8/8] Avvio interfaccia RustDesk...
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
echo.
echo [MaGa] Installazione completata con successo %DATE% %TIME% >> "%LOGFILE%"
goto :end

:error
echo.
echo ============================================
echo  ERRORE durante l'installazione!
echo  Consulta il log per i dettagli:
echo  %LOGFILE%
echo ============================================
echo.
echo [MaGa] Installazione FALLITA %DATE% %TIME% >> "%LOGFILE%"
pause

:end
