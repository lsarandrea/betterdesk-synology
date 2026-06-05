@echo off
setlocal

REM ================================================
REM  CONFIGURAZIONE — DA NON MODIFICARE
REM  I valori reali sono preimpostati sul file
REM  scaricabile da install.maganet.it
REM ================================================
set "SERVER=betterdesk.tuodominio.it"
set "PUBKEY=LA_TUA_CHIAVE_PUBBLICA="
set "API=http://betterdesk.tuodominio.it:21121"
set "PERMANENT_PWD=LatuaPasswordPermanente"
set "BDAGENT_SERVER=wss://betterdesk.tuodominio.it/cdap"
set "BDAGENT_API_KEY=LA_TUA_API_KEY"
set "BDAGENT_DIR=C:\ProgramData\BetterDesk"
set "SERVICE_NAME=BetterDeskAgent"
set "LOGFILE=C:\maga-install.log"

echo [MaGa] Installazione avviata %DATE% %TIME% > "%LOGFILE%"
echo ============================================
echo  [MaGa] Installazione RustDesk + Agente
echo ============================================
echo.

REM ================================================
REM  FASE 1 - PULIZIA COMPLETA
REM ================================================

echo [1/4] Stop tutti i processi...
echo [1/4] Stop processi >> "%LOGFILE%"
sc stop %SERVICE_NAME% >> "%LOGFILE%" 2>&1
sc stop RustDesk >> "%LOGFILE%" 2>&1
taskkill /F /IM RustDesk.exe >> "%LOGFILE%" 2>&1
taskkill /F /IM betterdesk-agent.exe >> "%LOGFILE%" 2>&1
timeout /t 5 /nobreak >nul

echo [2/4] Disinstallazione RustDesk precedente...
echo [2/4] Disinstallazione RustDesk >> "%LOGFILE%"
if exist "%ProgramFiles%\RustDesk\RustDesk.exe" (
  "%ProgramFiles%\RustDesk\RustDesk.exe" --uninstall >> "%LOGFILE%" 2>&1
  timeout /t 8 /nobreak >nul
)
sc delete RustDesk >> "%LOGFILE%" 2>&1
timeout /t 3 /nobreak >nul

echo [3/4] Rimozione servizio BetterDesk Agent...
echo [3/4] Rimozione Agent >> "%LOGFILE%"
if exist "%BDAGENT_DIR%\nssm.exe" (
  "%BDAGENT_DIR%\nssm.exe" remove %SERVICE_NAME% confirm >> "%LOGFILE%" 2>&1
)
sc delete %SERVICE_NAME% >> "%LOGFILE%" 2>&1

echo [4/4] Cancellazione FORZATA configurazioni precedenti...
echo [4/4] Pulizia file .toml >> "%LOGFILE%"
for %%D in (
  "%ProgramData%\RustDesk\config"
  "%SystemRoot%\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config"
  "%SystemRoot%\System32\config\systemprofile\AppData\Roaming\RustDesk\config"
  "%APPDATA%\RustDesk\config"
  "%USERPROFILE%\AppData\Roaming\RustDesk\config"
) do (
  if exist "%%~D" (
    del /F /Q "%%~D\RustDesk.toml"  >> "%LOGFILE%" 2>&1
    del /F /Q "%%~D\RustDesk2.toml" >> "%LOGFILE%" 2>&1
    echo   Pulito: %%~D >> "%LOGFILE%"
  )
)
rmdir /S /Q "%BDAGENT_DIR%" >> "%LOGFILE%" 2>&1
echo   Pulizia completata >> "%LOGFILE%"

REM ================================================
REM  FASE 2 - INSTALLAZIONE RUSTDESK
REM ================================================

echo.
echo [5/8] Download ultima versione RustDesk...
echo [5/8] Download RustDesk >> "%LOGFILE%"
powershell -NoProfile -Command "$url=(Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest').assets | Where-Object{$_.name -like '*-x86_64.exe'} | Select-Object -First 1 -ExpandProperty browser_download_url; Invoke-WebRequest -Uri $url -OutFile 'C:\rustdesk.exe' -UseBasicParsing" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE [5/8] download RustDesk >> "%LOGFILE%" & goto :error )

echo [6/8] Installazione silenziosa RustDesk...
echo [6/8] Installazione RustDesk >> "%LOGFILE%"
"C:\rustdesk.exe" --silent-install >> "%LOGFILE%" 2>&1
timeout /t 15 /nobreak >nul

REM Stop immediato post-install prima di scrivere config
sc stop RustDesk >> "%LOGFILE%" 2>&1
taskkill /F /IM RustDesk.exe >> "%LOGFILE%" 2>&1
timeout /t 5 /nobreak >nul

echo [7/8] Scrittura configurazione server MaGa...
echo [7/8] Scrittura config >> "%LOGFILE%"
for %%D in (
  "%ProgramData%\RustDesk\config"
  "%SystemRoot%\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config"
  "%SystemRoot%\System32\config\systemprofile\AppData\Roaming\RustDesk\config"
  "%APPDATA%\RustDesk\config"
  "%USERPROFILE%\AppData\Roaming\RustDesk\config"
) do (
  mkdir "%%~D" 2>nul
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
    echo permanent-password = '%PERMANENT_PWD%'
  ) > "%%~D\RustDesk2.toml"
  copy /Y "%%~D\RustDesk2.toml" "%%~D\RustDesk.toml" >nul 2>&1
  echo   Scritto: %%~D >> "%LOGFILE%"
)

REM ================================================
REM  FASE 3 - BETTERDESK AGENT
REM ================================================

echo [8/8] Installazione BetterDesk Agent...
echo [8/8] BetterDesk Agent >> "%LOGFILE%"

mkdir "%BDAGENT_DIR%" 2>nul
mkdir "%BDAGENT_DIR%\data" 2>nul

echo   Download NSSM...
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile 'C:\nssm.zip' -UseBasicParsing" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE download NSSM >> "%LOGFILE%" & goto :error )

powershell -NoProfile -Command "Expand-Archive -Path 'C:\nssm.zip' -DestinationPath 'C:\nssm' -Force" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE estrazione NSSM >> "%LOGFILE%" & goto :error )

powershell -NoProfile -Command "$f=Get-ChildItem 'C:\nssm' -Recurse -Filter 'nssm.exe' | Where-Object{$_.Directory -match 'win64'} | Select-Object -First 1; if($f){Copy-Item $f.FullName '%BDAGENT_DIR%\nssm.exe'}else{exit 1}" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE copia nssm.exe >> "%LOGFILE%" & goto :error )

echo   Download betterdesk-agent.exe...
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/UNITRONIX/BetterDesk/releases/latest/download/betterdesk-agent-windows-amd64.exe' -OutFile '%BDAGENT_DIR%\betterdesk-agent.exe' -UseBasicParsing" >> "%LOGFILE%" 2>&1
if errorlevel 1 (
  echo   Retry download agente con nome alternativo... >> "%LOGFILE%"
  powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/UNITRONIX/BetterDesk/releases/latest/download/betterdesk-agent.exe' -OutFile '%BDAGENT_DIR%\betterdesk-agent.exe' -UseBasicParsing" >> "%LOGFILE%" 2>&1
  if errorlevel 1 ( echo ERRORE download betterdesk-agent.exe >> "%LOGFILE%" & goto :error )
)

echo   Verifica dimensione agente scaricato...
for %%F in ("%BDAGENT_DIR%\betterdesk-agent.exe") do (
  echo   Dimensione: %%~zF bytes >> "%LOGFILE%"
  if %%~zF LSS 1000 ( echo ERRORE agente scaricato troppo piccolo, possibile 404 >> "%LOGFILE%" & goto :error )
)

echo   Scrittura config agente...
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

echo   Registrazione servizio...
"%BDAGENT_DIR%\nssm.exe" install %SERVICE_NAME% "%BDAGENT_DIR%\betterdesk-agent.exe" "-config \"%BDAGENT_DIR%\config.json\"" >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE install servizio NSSM >> "%LOGFILE%" & goto :error )

"%BDAGENT_DIR%\nssm.exe" set %SERVICE_NAME% Start SERVICE_AUTO_START >> "%LOGFILE%" 2>&1
"%BDAGENT_DIR%\nssm.exe" set %SERVICE_NAME% DisplayName "BetterDesk Agent" >> "%LOGFILE%" 2>&1

echo   Avvio servizio Agent...
sc start %SERVICE_NAME% >> "%LOGFILE%" 2>&1
if errorlevel 1 ( echo ERRORE avvio %SERVICE_NAME% >> "%LOGFILE%" & goto :error )

REM ================================================
REM  FASE 4 - AVVIO FINALE
REM ================================================

echo   Avvio RustDesk...
sc start RustDesk >> "%LOGFILE%" 2>&1
timeout /t 3 /nobreak >nul
start "" "%ProgramFiles%\RustDesk\RustDesk.exe" >nul 2>&1

echo.
echo ============================================
echo  Installazione completata!
echo  RustDesk  : %SERVER%
echo  Agente    : %BDAGENT_SERVER%
echo  Device    : %COMPUTERNAME%
echo  Log       : %LOGFILE%
echo ============================================
echo [MaGa] Completato %DATE% %TIME% >> "%LOGFILE%"
goto :end

:error
echo.
echo ============================================
echo  ERRORE durante l'installazione!
echo  Consulta il log: %LOGFILE%
echo ============================================
echo [MaGa] FALLITO %DATE% %TIME% >> "%LOGFILE%"
pause

:end
endlocal
