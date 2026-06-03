# BetterDesk + RustDesk su Synology NAS — Guida Completa

Installazione e configurazione di [BetterDesk](https://github.com/unitronix/betterdesk) (console di gestione per RustDesk) su Synology NAS con DSM 7.x.

> **⚠️ Versione immagine:** Usare l'immagine `2.3.0` (esportata dal NAS arancio come `betterdesk-images-2.4.0.tar.gz`). La versione `3.0.0` (tag `:latest` da giugno 2026) è una alpha con bug di autenticazione (`syncUserFromGo is not a function`). NON usare `:latest` finché non viene rilasciata una versione stabile.

---

## Struttura Repository

```
betterdesk-synology/
├── docker-compose.yml          ← Template generico (placeholder)
├── README.md                   ← Questa guida
├── TROUBLESHOOTING.md          ← Problemi noti e soluzioni
├── client-install/             ← Pagina web installazione client (template)
│   ├── index.html
│   ├── install-rustdesk-windows.bat
│   ├── install-rustdesk-macos.sh
│   └── install-rustdesk-linux.sh
└── maganet/                    ← Configurazione specifica MaGaServer1
    ├── docker-compose.yml      ← Compose compilato per betterdesk.maganet.it
    ├── README.md               ← Guida deploy MaGa
    └── client-install/
        ├── index.html          ← Pagina install.maganet.it
        ├── install-rustdesk-windows.bat
        ├── install-rustdesk-macos.sh
        └── install-rustdesk-linux.sh
```

---

## Installazione Rapida

### 1. Preparazione cartelle

```bash
mkdir -p /volume1/docker/betterdesk/server /volume1/docker/betterdesk/console/appdata
chown -R root:root /volume1/docker/betterdesk/server
chmod -R 755 /volume1/docker/betterdesk/server
chmod -R 777 /volume1/docker/betterdesk/console/appdata
```

### 2. Scarica il compose

```bash
curl -o /volume1/docker/betterdesk/docker-compose.yml \
  https://raw.githubusercontent.com/lsarandrea/betterdesk-synology/main/docker-compose.yml
```

### 3. Modifica le variabili

Edita `docker-compose.yml` e sostituisci:
- `YOUR_DOMAIN` → il tuo dominio (es. `betterdesk.tuodominio.it`)
- `YOUR_PUBLIC_IP` → IP pubblico del server
- `CHANGE_ME_PASSWORD` → password admin (usa `$$` per ogni `$` nella password)

### 4. Avvio

```bash
cd /volume1/docker/betterdesk
docker compose up -d
```

### 5. Verifica

```bash
sleep 40 && docker ps --filter name=betterdesk --format "table {{.Names}}\t{{.Status}}"
curl -s http://localhost:21114/api/health
```

---

## Configurazione DSM

### Reverse Proxy (obbligatorio per HTTPS)

In DSM → Pannello di Controllo → Portale di accesso → Proxy inverso:

| Origine | Destinazione |
|---|---|
| `https://betterdesk.tuodominio.it:443` | `http://localhost:5000` |
| `https://install.tuodominio.it:443` | cartella statica o `http://localhost:PORT` |

### Port Forwarding Router

Aprire le seguenti porte verso l'IP interno del NAS:

| Porta | Protocollo | Servizio |
|---|---|---|
| 21114 | TCP | API HTTP |
| 21115 | TCP | NAT Test |
| 21116 | TCP+UDP | Signal (HBBS) |
| 21117 | TCP | Relay (HBBR) |
| 21118 | TCP | WebSocket Signal |
| 21119 | TCP | WebSocket Relay |

---

## 🗺️ Roadmap

### ✅ Completato

- [x] Deploy BetterDesk su NAS arancio (`betterdesk.arancio.me`) — **funzionante**
- [x] Deploy BetterDesk su MaGaServer1 (`betterdesk.maganet.it`) — container **healthy** ✅
- [x] Container `betterdesk-server` e `betterdesk-console` entrambi `(healthy)` ✅
- [x] Reverse proxy DSM + SSL wildcard `*.maganet.it` attivo
- [x] Immagine v2.3.0 caricata (tar.gz da NAS arancio) — v3.0.0 alpha bypassata
- [x] Documentazione troubleshooting (11 problemi risolti/documentati)
- [x] Template generico con placeholder aggiornato
- [x] Cartella `maganet/` con configurazione specifica
- [x] Identificato DB di autenticazione corretto: `/appdata/auth.db` (non `db.sqlite3`)

### 🔴 PROBLEMA APERTO — Da risolvere (priorità massima)

- [ ] **Accesso a `https://betterdesk.maganet.it`** — login admin non funziona
  - La console usa `/appdata/auth.db` per l'autenticazione
  - L'hash in `auth.db` deve essere **bcrypt** (non PBKDF2)
  - Verificare le tabelle di `auth.db` e aggiornare con hash bcrypt corretto
  - Vedi **Problema #11** in TROUBLESHOOTING.md per la diagnosi completa

### 🔜 Da fare (in ordine, dopo risolto l'accesso)

1. **Recupero chiave pubblica** — `cat /volume1/docker/betterdesk/server/id_ed25519.pub`
2. **Aggiornare script client** in `maganet/client-install/` con la chiave pubblica reale
3. **Pagina `install.maganet.it`** — configurare reverse proxy DSM e verificare accesso
4. **Testare client RustDesk** — configurare un client con server `betterdesk.maganet.it`
5. **Branding MaGa** — logo, titolo "MaGa Remote", palette giallo `#d4a017`, pagina login personalizzata
6. **Agente remoto** su client arancio (mancante anche su arancio)
7. **Valutare aggiornamento** a versione stabile quando disponibile (dopo v3.0.0-alpha)

### 🔮 Futuro

- [ ] Rendere pubblico il repository come template
- [ ] Documentazione per altri provider (non solo Synology)
- [ ] Automazione deploy via script

---

## Problemi Noti

Vedi [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) per la lista completa.

**Problemi principali:**
- `permission denied` → `chmod 755` su `/server`, `chmod 777` su `/console/appdata`
- Pallino arancione Portainer → aggiungere `healthcheck` esplicito nel compose (già incluso)
- Password con `$` → usare `$$` nel compose
- v3.0.0 bug login → usare immagine 2.3.0/2.4.0 esportata da arancio
- **Login fallisce dopo reset manuale** → usare `/appdata/auth.db` (non `db.sqlite3`) e hash bcrypt
