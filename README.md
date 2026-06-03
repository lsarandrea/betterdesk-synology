# BetterDesk su Synology DS925+

> Guida completa e definitiva per l'installazione di BetterDesk (RustDesk Pro fork) su Synology NAS con DSM 7.x  
> **Dominio:** `betterdesk.maganet.it` | **Host:** `MaGaServer1` | **IP pubblico:** `217.198.140.12`

---

## Indice

1. [Prerequisiti](#1-prerequisiti)
2. [Struttura cartelle](#2-struttura-cartelle)
3. [Permessi e UID/GID](#3-permessi-e-uidgid)
4. [Configurazione docker-compose.yml](#4-configurazione-docker-composeyml)
5. [Installazione fresh start](#5-installazione-fresh-start)
6. [Verifica post-avvio](#6-verifica-post-avvio)
7. [Struttura Database](#7-struttura-database)
8. [Reverse Proxy Synology](#8-reverse-proxy-synology)
9. [Porte utilizzate](#9-porte-utilizzate)
10. [Immagini offline](#10-immagini-offline)
11. [Reset completo](#11-reset-completo)
12. [Roadmap](#12-roadmap)

---

## 1. Prerequisiti

- Synology DS925+ con DSM 7.x
- Docker e Container Manager installati dal Package Center
- Accesso SSH root al NAS
- Dominio `betterdesk.maganet.it` con certificato SSL (già configurato nel Reverse Proxy DSM)
- Immagini disponibili su `ghcr.io/unitronix/`:
  - `betterdesk-server:latest`
  - `betterdesk-console:latest`

---

## 2. Struttura cartelle

La struttura **deve essere creata manualmente prima** di avviare i container.

```
/volume1/docker/betterdesk/
├── docker-compose.yml
├── server/          ← dati server Go (chiavi, DB principale)
│   ├── id_ed25519           (generato al primo avvio)
│   ├── id_ed25519.pub       (generato al primo avvio)
│   ├── db_v2.sqlite3        (DB principale - dispositivi, sessioni)
│   ├── db_v2.sqlite3-shm    (generato automaticamente)
│   ├── db_v2.sqlite3-wal    (generato automaticamente)
│   ├── .api_key             (generato al primo avvio)
│   └── .enrollment_initialized (flag creato al primo avvio)
└── console/         ← dati console Node.js
    ├── appdata/             (cartella dati applicazione)
    │   └── (file runtime)
    ├── auth.db              ← DB autenticazione console (utenti, sessioni)
    ├── auth.db-shm
    ├── auth.db-wal
    ├── .session_secret      (generato al primo avvio)
    ├── agent-builds/        (build agenti)
    ├── build-cache/
    ├── chat-files/
    └── uploads/
```

### Creazione struttura

```bash
mkdir -p /volume1/docker/betterdesk/server
mkdir -p /volume1/docker/betterdesk/console/appdata
```

> ⚠️ **NON creare altri file o cartelle** — vengono tutti generati automaticamente al primo avvio.

---

## 3. Permessi e UID/GID

> ⚠️ **Questo è il punto critico più comune di fallimento su Synology.**

I container BetterDesk girano con **UID 10001 / GID 10001**. Le cartelle devono essere di proprietà di questo utente.

### Impostazione permessi corretti

```bash
chown -R 10001:10001 /volume1/docker/betterdesk/server
chown -R 10001:10001 /volume1/docker/betterdesk/console
```

### Verifica permessi

```bash
ls -la /volume1/docker/betterdesk/
ls -la /volume1/docker/betterdesk/server/
ls -la /volume1/docker/betterdesk/console/
```

Output atteso:
```
drwxr-xr-x  1 10001 10001  ... server/
drwxr-xr-x  1 10001 10001  ... console/
```

### Permessi speciali per appdata

La cartella `console/appdata` richiede permessi di scrittura estesi:

```bash
chown -R 10001:10001 /volume1/docker/betterdesk/console/appdata
chmod 755 /volume1/docker/betterdesk/console/appdata
```

---

## 4. Configurazione docker-compose.yml

```yaml
services:
  server:
    image: ghcr.io/unitronix/betterdesk-server:latest
    container_name: betterdesk-server
    hostname: betterdesk-server
    network_mode: host
    command:
      - "/usr/local/bin/betterdesk-server"
      - "-mode"
      - "all"
      - "-key-file"
      - "/opt/rustdesk/id_ed25519"
    volumes:
      - /volume1/docker/betterdesk/server:/opt/rustdesk
    environment:
      - ENCRYPTED_ONLY=1
      - DB_URL=/opt/rustdesk/db_v2.sqlite3
      - RELAY_SERVERS=betterdesk.maganet.it:21117
      - PUBLIC_IP=217.198.140.12
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:21114/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    restart: unless-stopped

  console:
    image: ghcr.io/unitronix/betterdesk-console:latest
    container_name: betterdesk-console
    hostname: betterdesk-console
    network_mode: host
    volumes:
      - /volume1/docker/betterdesk/server:/opt/rustdesk
      - /volume1/docker/betterdesk/console/appdata:/appdata
    environment:
      - NODE_ENV=production
      - PORT=5000
      - HOST=0.0.0.0
      - API_HOST=0.0.0.0
      - SERVER_BACKEND=localhost
      - HBBS_API_URL=http://localhost:21114/api
      - BETTERDESK_API_URL=http://localhost:21114/api
      - RUSTDESK_PATH=/opt/rustdesk
      - DATA_DIR=/appdata
      - DB_PATH=/opt/rustdesk/db_v2.sqlite3
      - PUB_KEY_PATH=/opt/rustdesk/id_ed25519.pub
      - API_KEY_PATH=/opt/rustdesk/.api_key
      - WS_HBBS_HOST=localhost
      - WS_HBBS_PORT=21116
      - WS_HBBR_HOST=localhost
      - WS_HBBR_PORT=21117
      - HBBS_WS_URL=ws://localhost:21118
      - HBBR_WS_URL=ws://localhost:21119
      - CDAP_URL=ws://localhost:21122/cdap
      - DOCKER=true
      - INIT_ADMIN_USER=admin
      - NODE_OPTIONS=--dns-result-order=ipv4first
    restart: unless-stopped
```

> ⚠️ **IMPORTANTE:** La console **non ha** `depends_on: server`. I due container si avviano in parallelo ma la console aspetta che il server sia pronto tramite retry interni.

---

## 5. Installazione fresh start

Procedura completa dall'inizio, in ordine **rigoroso**:

```bash
# 1. Crea cartella principale e struttura
mkdir -p /volume1/docker/betterdesk/server
mkdir -p /volume1/docker/betterdesk/console/appdata

# 2. Copia docker-compose.yml nella cartella
cd /volume1/docker/betterdesk

# 3. Carica immagini (se offline) — vedi sezione 10
# oppure verifica che siano già presenti:
docker images | grep betterdesk

# 4. Imposta permessi PRIMA di avviare
chown -R 10001:10001 server console
chmod 755 server console console/appdata

# 5. Verifica permessi
ls -la server/ && ls -la console/

# 6. Avvia i container
docker compose up -d

# 7. Attendi 15 secondi per l'inizializzazione
sleep 15

# 8. Verifica stato
docker compose ps

# 9. Controlla log avvio e recupera password admin
docker logs betterdesk-console 2>&1 | grep -i "password\|admin\|init\|created"
```

### Credenziali primo accesso

Dopo il primo avvio, la console crea automaticamente l'utente admin.
La password iniziale viene generata e mostrata nei log:

```bash
docker logs betterdesk-console 2>&1 | grep -i "password\|admin\|init\|created"
```

> ⚠️ **Leggi sempre i log al primo avvio** — la password iniziale è mostrata UNA SOLA VOLTA.

---

## 6. Verifica post-avvio

```bash
# Stato container
docker compose ps

# Health check server
curl -sf http://localhost:21114/api/health && echo "Server OK"

# Verifica console raggiungibile
curl -sf http://localhost:5000 -o /dev/null && echo "Console OK"

# Verifica porte RustDesk
ss -tlnp | grep -E '21114|21115|21116|21117|21118|21119'
```

### Stato atteso `docker compose ps`

```
NAME                   STATUS
betterdesk-server      Up (healthy)
betterdesk-console     Up
```

---

## 7. Struttura Database

> ⚠️ **BetterDesk usa DUE database SQLite separati.** Confonderli è la causa principale dei problemi di autenticazione.

### 7.1 `server/db_v2.sqlite3` — Database Server Go

Contiene dispositivi, peer, sessioni RustDesk.

**Tabelle principali:**

| Tabella | Contenuto |
|---|---|
| `peer` | Dispositivi registrati (id, hostname, OS, IP) |
| `group` | Gruppi di dispositivi |
| `user` | Utenti lato server Go (hash PBKDF2-SHA256) |
| `token` | Token di accesso API |

**Schema tabella `user`:**
```sql
CREATE TABLE user (
  guid TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  password TEXT,        -- hash PBKDF2-SHA256 formato: pbkdf2-sha256$iter$salt$hash
  email TEXT,
  note TEXT,
  status INTEGER,
  role INTEGER,
  is_admin INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### 7.2 `console/auth.db` — Database Console Node.js

Contiene utenti, sessioni, audit log della console web.

**Tabelle complete:**

| Tabella | Contenuto |
|---|---|
| `users` | Utenti console (username, password_hash bcrypt) |
| `access_tokens` | Token sessione |
| `login_attempts` | Tentativi di login (anti-brute-force) |
| `account_lockouts` | Account bloccati |
| `audit_log` | Log di tutte le azioni |
| `audit_connections` | Log connessioni remote |
| `audit_files` | Log trasferimenti file |
| `audit_alarms` | Log allarmi |
| `tickets` | Ticket di supporto |
| `ticket_comments` | Commenti ai ticket |
| `ticket_attachments` | Allegati ticket |
| `alert_rules` | Regole di alerting |
| `alert_history` | Storico alert |
| `remote_commands` | Comandi remoti |
| `folders` | Cartelle organizzazione dispositivi |
| `address_books` | Rubrica |
| `settings` | Impostazioni globali |
| `branding_config` | Personalizzazione UI |
| `relay_sessions` | Sessioni relay |
| `device_folder_assignments` | Assegnazione dispositivi a cartelle |
| `peer_sysinfo` | Info sistema dei peer |
| `peer_metrics` | Metriche performance peer |
| `user_groups` | Gruppi utenti |
| `user_group_members` | Membri gruppi |
| `device_groups` | Gruppi dispositivi |
| `device_group_members` | Membri gruppi dispositivi |
| `device_group_user_access` | Permessi utente su gruppi dispositivi |
| `device_group_user_group_access` | Permessi gruppo utenti su gruppi dispositivi |
| `strategies` | Strategie di accesso |

**Schema tabella `users`:**
```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,   -- bcrypt $2b$10$...
  email TEXT,
  role TEXT DEFAULT 'admin',
  is_active INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_login DATETIME
);
```

### 7.3 Formato hash

| Database | Algoritmo | Formato |
|---|---|---|
| `db_v2.sqlite3` (server Go) | PBKDF2-SHA256 | `pbkdf2-sha256$600000$<salt>$<hash>` |
| `auth.db` (console Node.js) | bcrypt | `$2b$10$<22char_salt><31char_hash>` |

> ⚠️ **NON mescolare gli hash** — inserire un hash bcrypt in `db_v2.sqlite3` o PBKDF2 in `auth.db` causa `hash type: unknown` nei log.

### 7.4 Generare hash bcrypt per auth.db

```bash
docker exec betterdesk-console node -e \
  "const b=require('bcrypt'); b.hash(process.argv[1],10).then(h=>console.log(h))" \
  -- 'LatuaPassword'
```

### 7.5 Aggiornare password admin in auth.db

```bash
# 1. Genera hash
HASH=$(docker exec betterdesk-console node -e \
  "const b=require('bcrypt'); b.hash(process.argv[1],10).then(h=>console.log(h))" \
  -- 'LatuaPassword')

# 2. Verifica hash generato
echo $HASH

# 3. Aggiorna DB
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "UPDATE users SET password_hash='$HASH' WHERE username='admin';"

# 4. Verifica
docker exec betterdesk-console sqlite3 /appdata/auth.db \
  "SELECT username, password_hash FROM users WHERE username='admin';"
```

---

## 8. Reverse Proxy Synology

Configurazione nel Pannello di Controllo DSM → Accesso Esterno → Proxy Inverso:

| Campo | Valore |
|---|---|
| Nome | betterdesk |
| Protocollo sorgente | HTTPS |
| Hostname sorgente | betterdesk.maganet.it |
| Porta sorgente | 443 |
| Protocollo destinazione | HTTP |
| Hostname destinazione | localhost |
| Porta destinazione | 5000 |

**Header WebSocket** (tab Intestazioni personalizzate):
```
Upgrade: $http_upgrade
Connection: $connection_upgrade
```

---

## 9. Porte utilizzate

| Porta | Protocollo | Servizio | Note |
|---|---|---|---|
| 5000 | TCP | Console web | Accesso via reverse proxy |
| 21114 | TCP | API server Go | Health check, API |
| 21115 | TCP | RustDesk NAT test | |
| 21116 | TCP/UDP | RustDesk HBBS | Registrazione ID |
| 21117 | TCP | RustDesk HBBR | Relay |
| 21118 | TCP | RustDesk WS | WebSocket HBBS |
| 21119 | TCP | RustDesk WS | WebSocket HBBR |
| 21122 | TCP | CDAP | Client Device Access Protocol |

> ⚠️ **Tutte le porte devono essere aperte** nel firewall Synology e nel router.

### Verifica porte aperte

```bash
ss -tlnp | grep -E '5000|21114|21115|21116|21117|21118|21119|21122'
```

---

## 10. Immagini offline

> ⚠️ **ATTENZIONE AL NOME DEL FILE:** Il file `betterdesk-images-2.4.0.tar.gz` presente in `/volume1/docker/` contiene in realtà le immagini della versione **2.3.0**, NON la 2.4.0. Il nome del file è fuorviante.

### Immagini contenute nel tar.gz

| Immagine | Versione reale |
|---|---|
| `ghcr.io/unitronix/betterdesk-server` | 2.3.0 |
| `ghcr.io/unitronix/betterdesk-console` | 2.3.0 |

### Caricamento immagini da file offline

```bash
# Carica le immagini nel Docker locale
docker load -i /volume1/docker/betterdesk-images-2.4.0.tar.gz

# Verifica immagini caricate
docker images | grep betterdesk
```

### Verifica versione immagine caricata

```bash
docker inspect ghcr.io/unitronix/betterdesk-console:latest | grep -i version
```

### Quando usare il file offline vs pull da internet

| Scenario | Metodo |
|---|---|
| NAS ha accesso a ghcr.io | `docker pull ghcr.io/unitronix/betterdesk-server:latest` |
| NAS senza accesso a ghcr.io | `docker load -i /volume1/docker/betterdesk-images-2.4.0.tar.gz` |
| Vuoi versione specifica (2.3.0) | Usa il file offline |
| Vuoi versione più recente | Pull da internet |

---

## 11. Reset completo

Quando si vuole ripartire da zero (installazione pulita):

```bash
# 1. Ferma e rimuovi container
cd /volume1/docker/betterdesk
docker compose down

# 2. Cancella TUTTA la cartella betterdesk
cd /volume1/docker
rm -rf betterdesk

# 3. Verifica pulizia
ls -la /volume1/docker/

# 4. Ricrea struttura da zero
mkdir -p /volume1/docker/betterdesk/server
mkdir -p /volume1/docker/betterdesk/console/appdata

# 5. Ricopia docker-compose.yml
# (dal repository GitHub o manualmente)

# 6. Imposta permessi
chown -R 10001:10001 /volume1/docker/betterdesk/server
chown -R 10001:10001 /volume1/docker/betterdesk/console
chmod 755 /volume1/docker/betterdesk/console/appdata

# 7. Riavvia
cd /volume1/docker/betterdesk
docker compose up -d

# 8. Attendi inizializzazione e leggi log
sleep 15
docker logs betterdesk-console 2>&1 | grep -i "password\|admin\|init\|created"
```

---

## 12. Roadmap

| # | Attività | Stato |
|---|---|---|
| 1 | Installazione server e console | ✅ Completato |
| 2 | Configurazione reverse proxy SSL | ✅ Completato |
| 3 | Caricamento immagini v2.3.0 offline | ✅ Completato |
| 4 | Risoluzione problema login admin | 🔄 In corso |
| 5 | Primo accesso e cambio password | ⏳ Pending |
| 6 | Configurazione client RustDesk | ⏳ Pending |
| 7 | Enrollment dispositivi MaGa | ⏳ Pending |
| 8 | Configurazione gruppi e permessi | ⏳ Pending |
| 9 | Test connessione remota completa | ⏳ Pending |
| 10 | Backup automatico DB | ⏳ Pending |

---

*Ultimo aggiornamento: 2026-06-04 | Host: MaGaServer1 | NAS: DS925+*
