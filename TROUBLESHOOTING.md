# BetterDesk — Troubleshooting e Problemi Noti

Questo file raccoglie tutti i problemi reali incontrati durante il deploy su Synology DSM 7.x,
le cause tecniche e le soluzioni applicate. Aggiornato con le sessioni Conv-01 → Conv-05.

---

## Problemi e Soluzioni

### 1. `permission denied` su `/opt/rustdesk/id_ed25519`
**Sintomo:** Il container `betterdesk-server` entra in crash loop.
**Log:** `Failed to initialize keypair: keys: failed to write private key: open /opt/rustdesk/id_ed25519: permission denied`
**Causa:** La cartella `/volume1/docker/betterdesk/server` è montata con permessi restrittivi da Synology.
**Soluzione:**
```bash
chown -R root:root /volume1/docker/betterdesk/server
chmod -R 755 /volume1/docker/betterdesk/server
```

---

### 2. `EACCES: permission denied, mkdir '/appdata/uploads'`
**Sintomo:** Il container `betterdesk-console` entra in crash loop.
**Log:** `Error: EACCES: permission denied, mkdir '/appdata/uploads'`
**Causa:** La cartella console è stata creata da root ma Node.js non riesce a scriverci.
**Soluzione:**
```bash
mkdir -p /volume1/docker/betterdesk/console/appdata
chmod -R 777 /volume1/docker/betterdesk/console/appdata
```

---

### 3. Pallino arancione (unhealthy) su `betterdesk-server` con `network_mode: host`
**Sintomo:** Il container è funzionante ma Portainer/Container Manager mostra lo stato arancione.
**Causa:** Con `network_mode: host` Docker non riesce a raggiungere il container tramite IP virtuale per l'health check integrato nell'immagine.
**Verifica funzionamento reale:**
```bash
curl -s http://localhost:21114/api/health
# Risposta attesa: {"status":"ok","uptime":"..."}
```
**Soluzione:** Aggiungere un healthcheck esplicito nel compose:
```yaml
healthcheck:
  test: ["CMD", "curl", "-sf", "http://localhost:21114/api/health"]
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 10s
```

---

### 4. Password con `$` nel compose viene interpretata come variabile d'ambiente
**Sintomo:** Warning `The "Maga2026" variable is not set. Defaulting to a blank string.`
**Causa:** Docker Compose interpreta `$` come inizio di variabile d'ambiente.
**Soluzione:** Raddoppiare ogni `$` nella password:
```yaml
# SBAGLIATO:
- INIT_ADMIN_PASS=$Maga2026$
# CORRETTO:
- INIT_ADMIN_PASS=$$Maga2026$$
```

---

### 5. `INIT_ADMIN_PASS` ignorata se il DB esiste già
**Sintomo:** La password impostata nel compose non funziona.
**Causa:** `INIT_ADMIN_PASS` viene usata solo al primo avvio, quando il DB non esiste ancora.
**Soluzione:** Se il DB esiste già, recuperare la password generata automaticamente:
```bash
cat /volume1/docker/betterdesk/server/.admincredentials 2>/dev/null || echo "file non presente"
# oppure leggere dai log al primo avvio:
docker logs betterdesk-console | grep -i "admin password"
```

---

### 6. Versione 3.0.0 (latest) — Bug `syncUserFromGo is not a function`
**Sintomo:** Login impossibile — il server Go accetta la password ma la console crasha.
**Log:** `Go server accepted password for 'admin' — syncing local account` poi `TypeError: db.syncUserFromGo is not a function`
**Causa:** La v3.0.0 è una alpha (pre-release) con bug nell'autenticazione. Il tag `latest` su ghcr.io puntava erroneamente a questa versione.
**Soluzione:** Usare la versione 2.3.0/2.4.0 esportata dal NAS arancio (su cui funziona) e importarla:
```bash
# Sul NAS arancio (SynStation):
docker save ghcr.io/unitronix/betterdesk-console:latest ghcr.io/unitronix/betterdesk-server:latest | gzip > /volume1/docker/betterdesk-images-2.4.0.tar.gz
# Trasferire il file su MaGaServer1 (via DSM File Station o scp)
# Su MaGaServer1:
docker load < /volume1/docker/betterdesk-images-2.4.0.tar.gz
# Verifica versione effettiva caricata:
docker exec betterdesk-console cat /app/package.json | grep '"version"'
# NOTA: il tar.gz potrebbe contenere la 2.3.0 invece della 2.4.0 — va bene uguale, entrambe stabili
```

---

### 7. Console non si connette al server: `ECONNREFUSED 127.0.0.1:21114` (IPv4 vs IPv6)
**Causa:** Node.js su alcune versioni risolve `localhost` in `::1` (IPv6) invece di `127.0.0.1` (IPv4).
**Soluzione:** Aggiungere questa variabile alla console:
```yaml
- NODE_OPTIONS=--dns-result-order=ipv4first
```

---

### 8. Relay usa IP Docker interno (`172.x.x.x`) invece dell'IP pubblico
**Causa:** Senza `PUBLIC_IP` e `RELAY_SERVERS`, il server annuncia l'IP della scheda Docker.
**Soluzione:** Aggiungere al server:
```yaml
environment:
  - PUBLIC_IP=<IP_PUBBLICO_SERVER>
  - RELAY_SERVERS=betterdesk.<tuodominio>:21117
```

---

### 9. `ss: command not found` su Synology
**Causa:** L'utility `ss` non è disponibile su Synology DSM.
**Soluzione alternativa:**
```bash
netstat -tlnp | grep <porta>
```

---

### 10. Bind mount fallito: directory non esiste
**Log:** `Bind mount failed: '/volume1/docker/betterdesk/console/appdata' does not exist`
**Soluzione:**
```bash
mkdir -p /volume1/docker/betterdesk/console/appdata
```

---

### 11. Login fallisce — hash `unknown` / mismatch PBKDF2 vs bcrypt (Conv-05)
**Sintomo:** Dopo tentativi di reset password manuale, il login continua a fallire.
**Log console:** `[AUTH] hash type: unknown, length: 118` oppure `[AUTH] Login failed: password mismatch for 'admin' (hash type: PBKDF2)`
**Causa:** Ci sono due database distinti:
- **Server Go** (`/opt/rustdesk/db_v2.sqlite3`): usa PBKDF2
- **Console Node.js** (appdata `db.sqlite3` o `auth.db`): usa bcrypt

Se si tenta di aggiornare manualmente `password_hash` con un hash bcrypt nel DB del **server**, l'autenticazione fallisce perché il server si aspetta PBKDF2. Viceversa se si inserisce PBKDF2 nella console.

**Diagnosi:**
```bash
# Controlla hash nel DB del server Go:
docker exec betterdesk-server sqlite3 /opt/rustdesk/db_v2.sqlite3 "SELECT username, password_hash FROM users WHERE username='admin';"
# hash PBKDF2 → inizia con: pbkdf2-sha256$...

# Controlla log autenticazione:
docker logs betterdesk-console --tail 30 | grep -i auth
# Se vedi "hash type: unknown" → il DB ha un hash non riconosciuto dalla console
```

**Soluzione — generare hash bcrypt corretto per il DB console:**
```bash
# Genera hash bcrypt con la password desiderata (es. $Maga2026$)
docker exec betterdesk-console node -e "const bcrypt=require('bcrypt');bcrypt.hash('\$Maga2026\$',10).then(h=>console.log(h))"
# Aggiorna il DB console con l'hash generato
docker exec betterdesk-console sqlite3 /appdata/auth.db "UPDATE users SET password_hash='<HASH_GENERATO>' WHERE username='admin';"
```

**Soluzione alternativa — usare la variabile `INIT_ADMIN_PASS` con `$$` escaped:**
> Funziona solo se il DB è vuoto o si usa `forceUpdate`. Se il DB esiste già, viene ignorata.

**⚠️ PROBLEMA APERTO (Conv-05):** Nonostante la generazione dell'hash bcrypt corretto,
il login su `https://betterdesk.maganet.it` continua a fallire. La Console Node.js usa `auth.db`
come database primario di autenticazione (non `db.sqlite3`). Verificare il path esatto:
```bash
docker exec betterdesk-console ls /appdata/
# Risultato atteso: agent-builds auth.db auth.db-shm auth.db-wal build-cache db.sqlite3 uploads
# Il DB di autenticazione è auth.db, NON db.sqlite3!
docker exec betterdesk-console sqlite3 /appdata/auth.db ".tables"
```

---

## Checklist Pre-Avvio

Prima di eseguire `docker compose up -d` su un nuovo server:

- [ ] Cartelle create: `mkdir -p /volume1/docker/betterdesk/server /volume1/docker/betterdesk/console/appdata`
- [ ] Permessi server: `chown -R root:root /volume1/docker/betterdesk/server && chmod -R 755 /volume1/docker/betterdesk/server`
- [ ] Permessi console: `chmod -R 777 /volume1/docker/betterdesk/console/appdata`
- [ ] Porte libere: `netstat -tlnp | grep -E '2111[4-9]|5000'`
- [ ] Password `$` escaped come `$$` nel compose
- [ ] DNS sottodomini configurati e propagati
- [ ] Reverse proxy DSM: `betterdesk.<dominio>:443` → `localhost:5000`
- [ ] Certificato SSL valido per i sottodomini
- [ ] Port forwarding router: 21115–21119 TCP+UDP → IP interno del NAS

---

## Comandi Diagnostica Utili

```bash
# Stato container
docker ps --filter name=betterdesk --format "table {{.Names}}\t{{.Status}}"

# Log server (ultimi 20 righe)
docker logs betterdesk-server --tail 20

# Log console (ultimi 20 righe)
docker logs betterdesk-console --tail 20

# Health check manuale
curl -s http://localhost:21114/api/health

# Versione console
docker exec betterdesk-console cat /app/package.json | grep '"version"'

# Lista tabelle DB server Go
docker exec betterdesk-server sqlite3 /opt/rustdesk/db_v2.sqlite3 ".tables"

# Lista tabelle DB console (auth.db è quello usato per il login!)
docker exec betterdesk-console sqlite3 /appdata/auth.db ".tables"

# Hash password admin nel DB server
docker exec betterdesk-server sqlite3 /opt/rustdesk/db_v2.sqlite3 "SELECT username, password_hash FROM users WHERE username='admin';"

# Porte occupate
netstat -tlnp | grep -E '2111[4-9]|5000'
```
