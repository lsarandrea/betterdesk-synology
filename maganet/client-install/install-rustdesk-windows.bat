@echo off
set SERVER=betterdesk.maganet.it
set PUBKEY=w647yKhUkY49QHb/UxomU8oq0ZEf+nVF5+TiNlqHQFg=
set API=http://betterdesk.maganet.it:21121
set PERMANENT_PWD=MaGa2026

echo [MaGa] Installazione RustDesk...
echo.

echo [1/5] Download ultima versione RustDesk...
powershell -Command "$url = (Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest').assets | Where-Object { $_.name -like '*-x86_64.exe' } | Select-Object -First 1 -ExpandProperty browser_download_url; Invoke-WebRequest -Uri $url -OutFile '%TEMP%\rustdesk.exe' -UseBasicParsing"

echo [2/5] Stop servizio e processi RustDesk (incluse precedenti installazioni)...
sc stop RustDesk 2>nul
taskkill /F /IM RustDesk.exe 2>nul
timeout /t 3 /nobreak >nul

echo [3/5] Installazione silenziosa...
"%TEMP%\rustdesk.exe" --silent-install
timeout /t 8 /nobreak >nul

echo [4/5] Configurazione server MaGa (tutti i percorsi)...
rem Ferma nuovamente dopo l'installazione per poter scrivere la config
sc stop RustDesk 2>nul
taskkill /F /IM RustDesk.exe 2>nul
timeout /t 3 /nobreak >nul

rem --- PERCORSO 1: ProgramData (installazione standard come servizio) ---
set CONFIGDIR1=%ProgramData%\RustDesk\config
mkdir "%CONFIGDIR1%" 2>nul
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
) > "%CONFIGDIR1%\RustDesk2.toml"
copy "%CONFIGDIR1%\RustDesk2.toml" "%CONFIGDIR1%\RustDesk.toml" >nul

rem --- PERCORSO 2: LocalService profile (servizio gira come LocalSystem/LocalService) ---
set CONFIGDIR2=%SystemRoot%\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config
mkdir "%CONFIGDIR2%" 2>nul
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
) > "%CONFIGDIR2%\RustDesk2.toml"
copy "%CONFIGDIR2%\RustDesk2.toml" "%CONFIGDIR2%\RustDesk.toml" >nul

rem --- PERCORSO 3: System32 profile (LocalSystem) ---
set CONFIGDIR3=%SystemRoot%\System32\config\systemprofile\AppData\Roaming\RustDesk\config
mkdir "%CONFIGDIR3%" 2>nul
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
) > "%CONFIGDIR3%\RustDesk2.toml"
copy "%CONFIGDIR3%\RustDesk2.toml" "%CONFIGDIR3%\RustDesk.toml" >nul

rem --- PERCORSO 4: AppData utente corrente (sessione interattiva) ---
set CONFIGDIR4=%APPDATA%\RustDesk\config
mkdir "%CONFIGDIR4%" 2>nul
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
) > "%CONFIGDIR4%\RustDesk2.toml"
copy "%CONFIGDIR4%\RustDesk2.toml" "%CONFIGDIR4%\RustDesk.toml" >nul

rem --- Password permanente via PowerShell (RustDesk >= 1.2) ---
powershell -NoProfile -Command ^
  "& { $p = '%PERMANENT_PWD%'; " ^
  "  $paths = @('%CONFIGDIR1%','%CONFIGDIR2%','%CONFIGDIR3%','%CONFIGDIR4%'); " ^
  "  foreach($d in $paths) { " ^
  "    $f = Join-Path $d 'RustDesk2.toml'; " ^
  "    if (Test-Path $f) { " ^
  "      $c = Get-Content $f -Raw; " ^
  "      if ($c -notmatch 'permanent-password') { " ^
  "        $c = $c.TrimEnd() + \"`npermanent-password = '$p'`n\"; " ^
  "        Set-Content -Path $f -Value $c -Encoding UTF8; " ^
  "        Copy-Item $f (Join-Path $d 'RustDesk.toml') -Force; " ^
  "      } else { " ^
  "        $c = $c -replace \"permanent-password = '.*'\",\"permanent-password = '$p'\"; " ^
  "        Set-Content -Path $f -Value $c -Encoding UTF8; " ^
  "        Copy-Item $f (Join-Path $d 'RustDesk.toml') -Force; " ^
  "      } " ^
  "    } " ^
  "  } " ^
  "}"

echo [5/5] Avvio servizio RustDesk con nuova configurazione...
sc start RustDesk 2>nul
timeout /t 3 /nobreak >nul

echo.
echo  ============================================
echo   [MaGa] Configurazione completata!
echo   Server : %SERVER%
echo   API    : %API%
echo   Pwd    : %PERMANENT_PWD%
echo  ============================================
echo.
start "" "%ProgramFiles%\RustDesk\RustDesk.exe" 2>nul
