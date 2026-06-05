# Troubleshooting BetterDesk — Synology DS925+

> Raccolta completa di tutti i problemi riscontrati e relative soluzioni.

---

## Indice problemi

1. [Permission denied su cartelle](#1-permission-denied-su-cartelle)
2. [Container non si avvia — exec format error](#2-container-non-si-avvia--exec-format-error)
3. [Porta occupata](#3-porta-occupata)
4. [Immagine non trovata](#4-immagine-non-trovata)
5. [Hash type unknown nei log](#5-hash-type-unknown-nei-log)
6. [Login fallisce — password mismatch bcrypt](#6-login-fallisce--password-mismatch-bcrypt)
7. [Console non raggiunge il server](#7-console-non-raggiunge-il-server)
8. [auth.db vs db_v2.sqlite3 — confusione DB](#8-authdb-vs-db_v2sqlite3--confusione-db)
9. [Grep con --include non funziona su BusyBox](#9-grep-con---include-non-funziona-su-busybox)
10. [Container healthy ma login impossibile](#10-container-healthy-ma-login-impossibile)
11. [Reset password con variabile d'ambiente e $ nel valore](#11-reset-password-con-variabile-dambiente-e--nel-valore)
12. [Script Windows — config RustDesk precedente non rimossa](#12-script-windows--config-rustdesk-precedente-non-rimossa)
13. [Password admin console web si resetta ad ogni riavvio](#13-password-admin-console-web-si-resetta-ad-ogni-riavvio)

---

## 1. Permission denied su cartelle

**Sintomo nei log:**
```
permission denied: /opt/rustdesk/db_v2.sqlite3
permission denied: /appdata/auth.db
```

**Causa:** Le cartelle montate come volume non hanno UID/GID 10001 come owner.

**Soluzione:**
```bash
chown -R 10001:10001 /volume1/docker/betterdesk/server
chown -R 10001:10001 /volume1/docker/betterdesk/console
chmod 755 /volume1/docker/betterdesk/console/appdata
docker compose restart
```

**Prevenzione:** Impostare i permessi SEMPRE prima di `docker compose up -d`.

---

## 2. Container non si avvia — exec format error

**Sintomo:**
```
exec /usr/local/bin/betterdesk-server: exec format error
```

**Causa:** Immagine compilata per architettura diversa (es. amd64 su ARM o viceversa).

**Soluzione:**
```bash
# Verifica architettura NAS
uname -m

# Verifica architettura immagine
docker inspect ghcr.io/unitronix/betterdesk-server:latest | grep Architecture

# Pull forzato immagine corretta
docker pull --platform linux/amd64 ghcr.io/unitronix/betterdesk-server:latest
```

---

## 3. Porta occupata

**Sintomo:**
```
Error: bind: address already in use :21116
```

**Causa:** Un altro processo o una vecchia istanza del container occupa la porta.

**Soluzione:**
```bash
# Trova processo sulla porta
ss -tlnp | grep 21116

# Oppure
netstat -tlnp | grep 21116

# Ferma il processo se è un vecchio container
docker ps -a | grep betterdesk
docker rm -f betterdesk-server betterdesk-console
```

---

## 4. Immagine non trovata

**Sintomo:**
```
Unable to find image 'ghcr.io/unitronix/betterdesk-console:latest'
```

**Causa:** Problema di autenticazione al registry o rete.

**Soluzione:**
```bash
# Test connettività
curl -I https://ghcr.io

# Pull manuale
docker pull ghcr.io/unitronix/betterdesk-server:latest
docker pull ghcr.io/unitronix/betterdesk-console:latest
```

---

## 5. Hash type unknown nei log

**Sintomo nei log:**
```
[AUTH] Verifying password for 'admin' (hash type: unknown, length: 118)
[AUTH] Login failed: password mismatch for 'admin' (hash type: unknown)
```

**Causa:** Il campo `password_hash` in `auth.db` contiene un hash PBKDF2 (formato server Go) invece di bcrypt (formato console Node.js). Lunghezza 118 = PBKDF2, lunghezza 60 = bcrypt.

**Diagnosi:**
```bash
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "SELECT username, password_hash FROM users WHERE username='admin';"
```

Se inizia con `pbkdf2-sha256$...` → hash sbagliato nel DB sbagliato.

**Soluzione:** Vedi [Problema #6](#6-login-fallisce--password-mismatch-bcrypt).

**Prevenzione:** Non copiare mai hash da `db_v2.sqlite3` in `auth.db`.

---

## 6. Login fallisce — password mismatch bcrypt

**Sintomo nei log:**
```
[AUTH] Verifying password for 'admin' (hash type: bcrypt, length: 60)
[AUTH] Login failed: password mismatch for 'admin' (hash type: bcrypt)
```

**Causa:** L'hash bcrypt in `auth.db` non corrisponde alla password inserita, oppure la password contiene caratteri speciali che vengono interpretati dalla shell durante la generazione dell'hash.

**Soluzione corretta** (evita problemi di escaping con `$`):

```bash
# Crea file temporaneo con la password
docker exec betterdesk-console sh -c \
  "node -e \"const b=require('bcrypt'); b.hash(process.argv[1],10).then(h=>console.log(h))\" -- 'LatuaPassword'"
```

Oppure usa variabile d'ambiente per evitare escaping:
```bash
# Genera hash passando la password come argomento diretto
docker exec betterdesk-console node -e \
  "const b=require('bcrypt'); b.hash(process.argv[1],10).then(h=>console.log(h))" \
  -- 'LatuaPassword'
```

Poi aggiorna il DB:
```bash
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "UPDATE users SET password_hash='HASH_GENERATO' WHERE username='admin';"
```

**Verifica:**
```bash
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "SELECT username, password_hash FROM users WHERE username='admin';"
```

L'hash deve iniziare con `$2b$10$` e avere lunghezza 60.

---

## 7. Console non raggiunge il server

**Sintomo nei log console:**
```
connection refused http://localhost:21114/api
ECONNREFUSED 127.0.0.1:21114
```

**Causa:** Il server Go non è ancora pronto o non è in esecuzione.

**Diagnosi:**
```bash
# Verifica server in esecuzione
docker ps | grep betterdesk-server

# Verifica health
curl -sf http://localhost:21114/api/health && echo "OK"

# Verifica log server
docker logs betterdesk-server --tail 30
```

**Soluzione:**
```bash
# Riavvia in ordine
docker restart betterdesk-server
sleep 10
docker restart betterdesk-console
```

---

## 8. auth.db vs db_v2.sqlite3 — confusione DB

**Problema:** BetterDesk usa DUE database con strutture diverse.

| | `server/db_v2.sqlite3` | `console/auth.db` |
|---|---|---|
| Gestito da | Server Go | Console Node.js |
| Mount path | `/opt/rustdesk/db_v2.sqlite3` | `/appdata/auth.db` |
| Tabella utenti | `user` | `users` |
| Algoritmo hash | PBKDF2-SHA256 | bcrypt |
| Hash length | ~118 caratteri | 60 caratteri |

**Query rapida per identificare DB corretto:**
```bash
# Tabelle in auth.db
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "SELECT name FROM sqlite_master WHERE type='table';"

# Tabelle in db_v2.sqlite3
docker exec betterdesk-server sqlite3 /opt/rustdesk/db_v2.sqlite3 \
  "SELECT name FROM sqlite_master WHERE type='table';"
```

---

## 9. Grep con --include non funziona su BusyBox

**Sintomo:**
```
grep: unrecognized option '--include'
```

**Causa:** I container usano BusyBox grep che non supporta `--include`.

**Soluzione — usa `find + grep`:**
```bash
# SBAGLIATO (non funziona su BusyBox)
grep -r --include="*.js" "password" /app

# CORRETTO
find /app -name "*.js" -exec grep -l "password" {} \;
```

---

## 10. Container healthy ma login impossibile

**Sintomo:** `docker compose ps` mostra `(healthy)` ma il login alla console web fallisce sempre.

**Checklist diagnostica:**

```bash
# 1. Verifica log in tempo reale durante il login
docker logs betterdesk-console -f
# (poi tenta il login dal browser)

# 2. Controlla hash nel DB
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "SELECT username, password_hash, is_active FROM users;"

# 3. Controlla account lockout
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "SELECT * FROM account_lockouts;"

# 4. Controlla tentativi falliti
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "SELECT * FROM login_attempts ORDER BY created_at DESC LIMIT 10;"

# 5. Se account è bloccato, sblocca
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "DELETE FROM account_lockouts WHERE username='admin';"
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "DELETE FROM login_attempts WHERE username='admin';"
```

---

## 11. Reset password con variabile d'ambiente e $ nel valore

**Problema:** Password che contengono `$` (es. `$Maga2026$`) vengono interpretate dalla shell anche dentro singole virgolette in alcuni contesti.

**Sintomo:** Hash generato correttamente ma bcrypt.compare fallisce.

**Soluzione — usa `process.argv` invece di stringa diretta:**

```bash
# CORRETTO: passa password come argomento argv (non interpolato dalla shell)
docker exec betterdesk-console node -e \
  "const b=require('bcrypt'); b.hash(process.argv[1],10).then(h=>console.log(h))" \
  -- 'LatuaPassword123'
```

**Prevenzione:** Per password con caratteri speciali (`$`, `!`, `#`, `@`), usare sempre `process.argv[1]` e passare la password dopo `--`.

---

## 12. Script Windows — config RustDesk precedente non rimossa

**Sintomo:** Dopo l'installazione tramite script, RustDesk continua a puntare al server precedente (es. `betterdesk.arancio.me`) invece di quello nuovo.

**Causa:** Lo script non cancellava esplicitamente i file `.toml` esistenti prima di riscrivere la configurazione. RustDesk al primo avvio post-install **ricrea i `.toml` dai propri valori interni** se li trova già validi in uno dei percorsi. Inoltre, il servizio RustDesk veniva riavviato troppo presto (timeout insufficiente), sovrascrivendo i file di config appena scritti.

**I percorsi coinvolti:**
```
C:\ProgramData\RustDesk\config\RustDesk2.toml
C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml
C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\config\RustDesk2.toml
C:\Users\Public\RustDesk\config\RustDesk2.toml
```

**Fix applicato allo script:**
1. Aggiunto **step 2** dedicato: stop aggressivo del servizio + `DEL /F /Q` di tutti i `.toml` nei 4 percorsi **prima** dell'installazione
2. Timeout post-installazione aumentato a **15 secondi** (era troppo breve)
3. Aggiunto secondo stop post-installazione **prima** di scrivere i nuovi `.toml`
4. La scrittura della config avviene ora in **9 step** con `goto :error` su ogni step critico

**Diagnosi manuale** (se il problema persiste):
```powershell
# Controlla quale toml è attivo
Get-Content "C:\ProgramData\RustDesk\config\RustDesk2.toml"

# Cerca tutti i toml nel sistema
Get-ChildItem -Path C:\ -Recurse -Filter "RustDesk2.toml" -ErrorAction SilentlyContinue | Select-Object FullName
```

**Prevenzione:** Eseguire sempre lo script con diritti di Amministratore. Verificare il log `C:\maga-install.log` dopo ogni esecuzione.

---

## 13. Password admin console web si resetta ad ogni riavvio

**Sintomo:** Dopo `docker compose restart` (o riavvio del NAS), la password dell'utente admin torna a quella generata casualmente al primo avvio del container.

**Causa:** Confermata dalla documentazione ufficiale BetterDesk (`docker-entrypoint.sh`): *"The Node.js application handles all database initialization, migration, and admin user creation automatically on startup."* Al riavvio, se `auth.db` risulta mancante o il volume non è persistente, la console **ricrea l'utente admin con password casuale**.

**Le cause più comuni:**

| Causa | Sintomo aggiuntivo |
|---|---|
| Volume `console/appdata` non persistente | `auth.db` non trovato dopo riavvio |
| Mount errato nel `docker-compose.yml` | Path assoluto sbagliato |
| Permessi errati | `auth.db` non scrivibile → ricreato vuoto |
| Variabile `INITADMINUSER` che forza recreazione | Log mostra "Creating admin user" ad ogni avvio |

**Diagnosi:**
```bash
# 1. Verifica che auth.db esista e persista
ls -la /volume1/docker/betterdesk/console/appdata/

# 2. Verifica che il volume sia montato correttamente
docker inspect betterdesk-console | grep -A5 Mounts

# 3. Controlla i log all'avvio per "Creating admin user"
docker logs betterdesk-console | grep -i "admin\|init\|creat"
```

**Soluzione:**

Verificare che nel `docker-compose.yml` il volume sia corretto:
```yaml
# CORRETTO
volumes:
  - /volume1/docker/betterdesk/console/appdata:/appdata
```

Verificare i permessi:
```bash
chown -R 10001:10001 /volume1/docker/betterdesk/console/appdata
chmod 755 /volume1/docker/betterdesk/console/appdata
```

> ⚠️ **Regola fondamentale:** Le password degli utenti **NON** devono essere preimpostate nello script o nel compose. La password admin va impostata dalla UI **dopo il primo avvio**, e il volume `appdata` deve essere persistente per mantenerla.

**Procedura corretta al primo avvio:**
1. Avviare i container: `docker compose up -d`
2. Attendere che la console sia healthy: `docker compose ps`
3. Leggere la password generata dai log: `docker logs betterdesk-console | grep -i password`
4. Accedere alla console web e **cambiare immediatamente** la password da Impostazioni > Profilo
5. Verificare che `auth.db` esista sul volume host
6. **Non rimuovere mai** la cartella `console/appdata` senza backup

---

*Ultimo aggiornamento: 2026-06-05 | Host: MaGaServer1*
