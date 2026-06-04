# BetterDesk — Configurazione MaGa

Configurazione specifica per il server **MaGaServer1** (Synology DS925+).

## Dettagli ambiente

| Parametro | Valore |
|-----------|--------|
| Host | `betterdesk.maganet.it` |
| IP pubblico | `217.198.140.12` |
| Pagina install client | `https://install.maganet.it` |
| Volume base | `/volume1/docker/betterdesk/` |
| NAS modello | Synology DS925+ |

## Percorsi dati server (rilevati)

| File | Percorso |
|------|----------|
| Database SQLite | `/volume1/docker/betterdesk/server/db_v2.sqlite3` |
| API Key BetterDesk | `/volume1/docker/betterdesk/server/.api_key` |
| Chiave privata RustDesk | `/volume1/docker/betterdesk/server/id_ed25519` |
| Chiave pubblica RustDesk | `/volume1/docker/betterdesk/server/id_ed25519.pub` |
| Volume montato (container) | `Source: /volume1/docker/betterdesk/server` → `Destination: /opt/rustdesk` |

> ⚠️ Il file `.api_key` contiene la API Key in chiaro. Non condividerlo pubblicamente.

## Dati di configurazione client

| Parametro | Valore |
|-----------|--------|
| ID Server | `betterdesk.maganet.it` |
| Relay Server | `betterdesk.maganet.it` |
| RustDesk Public Key | `aWx/E8jZs/B0ENnJNRAcLgNnfij6ajUHLzgLy97RABo=` |
| API Key (parziale) | `2d9f...3fc0` (completa in `.api_key` sul server) |
| Password fissa client RustDesk | `Mg2026Rsk` |
| Porta CDAP agente | `21122` |

## Deploy

### 1. Preparare le cartelle

```bash
mkdir -p /volume1/docker/betterdesk/server
mkdir -p /volume1/docker/betterdesk/console
```

### 2. Copiare il compose

```bash
scp maganet/docker-compose.yml admin@MaGaServer1:/volume1/docker/betterdesk/
```

### 3. Avviare i container

```bash
cd /volume1/docker/betterdesk
docker compose up -d
```

### 4. Recuperare la chiave pubblica

```bash
cat /volume1/docker/betterdesk/server/id_ed25519.pub
```

### 5. Recuperare la API Key

```bash
cat /volume1/docker/betterdesk/server/.api_key
```

### 6. Pubblicare i file su install.maganet.it

```bash
mkdir -p /volume1/web/install
curl -sL "https://raw.githubusercontent.com/lsarandrea/betterdesk-synology/main/maganet/client-install/index.html" -o /volume1/web/install/index.html
curl -sL "https://raw.githubusercontent.com/lsarandrea/betterdesk-synology/main/maganet/client-install/install-rustdesk-windows.bat" -o /volume1/web/install/install-rustdesk-windows.bat
curl -sL "https://raw.githubusercontent.com/lsarandrea/betterdesk-synology/main/maganet/client-install/install-rustdesk-linux.sh" -o /volume1/web/install/install-rustdesk-linux.sh
curl -sL "https://raw.githubusercontent.com/lsarandrea/betterdesk-synology/main/maganet/client-install/install-rustdesk-macos.sh" -o /volume1/web/install/install-rustdesk-macos.sh
curl -sL "https://raw.githubusercontent.com/lsarandrea/betterdesk-synology/main/maganet/client-install/install-agent-linux.sh" -o /volume1/web/install/install-agent-linux.sh
curl -sL "https://raw.githubusercontent.com/lsarandrea/betterdesk-synology/main/maganet/client-install/install-agent-windows.ps1" -o /volume1/web/install/install-agent-windows.ps1
chmod 644 /volume1/web/install/*
```

## Reverse proxy DSM

- **betterdesk.maganet.it** `(HTTPS :443)` → `http://localhost:5000`
- **install.maganet.it** `(HTTPS :443)` → cartella statica `/volume1/web/install/`

## Porte da aprire sul router

| Porta | Protocollo | Servizio |
|-------|-----------|----------|
| 21114 | TCP | API HTTP (interna) |
| 21115 | TCP | hbbs - NAT type test |
| 21116 | TCP/UDP | hbbs - Registrazione/heartbeat |
| 21117 | TCP | hbbr - Relay |
| 21118 | TCP | hbbs - WebSocket |
| 21119 | TCP | hbbr - WebSocket |
| 21122 | TCP | CDAP agente BetterDesk |
| 5000  | TCP | Console web (interna, solo reverse proxy) |
