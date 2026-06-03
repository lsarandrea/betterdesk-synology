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

### 5. Aggiornare gli script client

Sostituisci `YOUR_PUBLIC_KEY` in `client-install/` con la chiave ottenuta al punto 4,
poi pubblica i file su `install.maganet.it`.

## Reverse proxy DSM

- **betterdesk.maganet.it** `(HTTPS :443)` → `http://localhost:5000`
- **install.maganet.it** `(HTTPS :443)` → cartella statica con i file `client-install/`

## Porte da aprire sul router

| Porta | Protocollo | Servizio |
|-------|-----------|----------|
| 21114 | TCP | API HTTP (interna) |
| 21115 | TCP | hbbs - NAT type test |
| 21116 | TCP/UDP | hbbs - Registrazione/heartbeat |
| 21117 | TCP | hbbr - Relay |
| 21118 | TCP | hbbs - WebSocket |
| 21119 | TCP | hbbr - WebSocket |
| 5000  | TCP | Console web (interna, solo reverse proxy) |
