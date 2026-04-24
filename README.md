# BetterDesk + RustDesk su Synology NAS

**Template generico** per il deploy di un server self-hosted di controllo remoto basato su **RustDesk** e **BetterDesk** su Synology NAS.

Questa repository **non contiene domini hardcoded** — tutti i valori specifici sono rappresentati da **placeholder** che vanno sostituiti con i tuoi dati.

---

## 📋 Indice

- [Prerequisiti](#prerequisiti)
- [Architettura](#architettura)
- [Porte utilizzate](#porte-utilizzate)
- [🛠️ Installazione](#%EF%B8%8F-installazione)
  - [1. Preparazione ambiente](#1-preparazione-ambiente)
  - [2. Configurazione DNS e porte](#2-configurazione-dns-e-porte)
  - [3. Sostituzione placeholder](#3-sostituzione-placeholder)
  - [4. Deploy dei container](#4-deploy-dei-container)
  - [5. Recupero chiave pubblica](#5-recupero-chiave-pubblica)
  - [6. Configurazione client](#6-configurazione-client)
- [📝 Tabella completa placeholder](#-tabella-completa-placeholder)
- [Struttura della repository](#struttura-della-repository)
- [Troubleshooting](#troubleshooting)
- [Aggiornamento](#aggiornamento)

---

## Prerequisiti

- **Synology NAS** con Docker/Container Manager installato
- **Dominio pubblico** che punta al tuo IP (es. `rustdesk.miodominio.com`)
- **Port forwarding** sul router per le porte 21115–21119 e 21121 (TCP/UDP)
- **Reverse proxy** configurato in DSM che punta `https://tuo-dominio:443` → `localhost:5000`
- **Certificato SSL** valido (Let's Encrypt via DSM)

---

## Architettura

```
Client RustDesk (Windows/macOS/Linux)
        │
        ▼
YOUR_DOMAIN (Router → Synology NAS)
        │
        ├── hbbs  (Signal Server)   :21115, :21116, :21118
        ├── hbbr  (Relay Server)    :21117, :21119
        └── Console Web             :5000  → Reverse proxy → :443
```

**Reverse proxy DSM:** `https://YOUR_DOMAIN:443` → `http://localhost:5000`

---

## Porte utilizzate

| Porta | Protocollo | Servizio |
|-------|-----------|----------|
| 21114 | TCP | API HTTP (interna) |
| 21115 | TCP | hbbs - NAT type test |
| 21116 | TCP/UDP | hbbs - Registrazione/heartbeat |
| 21117 | TCP | hbbr - Relay |
| 21118 | TCP | hbbs - WebSocket |
| 21119 | TCP | hbbr - WebSocket |
| 21121 | TCP | API client RustDesk |
| 5000 | TCP | Console web (interna) |

> Tutte le porte **21115–21119** e **21121** devono essere in **port forwarding** sul router.

---

## 🛠️ Installazione

### 1. Preparazione ambiente

Creare la cartella dati sul NAS (via SSH o DSM File Station):

```bash
mkdir -p /volume1/docker/betterdesk/data
```

> ⚠️ Sostituisci `/volume1` con il tuo volume reale se diverso.

### 2. Configurazione DNS e porte

1. **DNS:** Punta il tuo dominio (es. `rustdesk.tuodominio.com`) all'IP pubblico del router
2. **Port forwarding:** Configura il router per inoltrare le porte **21115–21119** e **21121** all'IP del NAS
3. **Reverse proxy DSM:** In Pannello di controllo DSM → Reverse Proxy, crea una regola:
   - Origine: `https://YOUR_DOMAIN:443`
   - Destinazione: `http://localhost:5000`
4. **Certificato SSL:** Associa il certificato Let's Encrypt al dominio in DSM

### 3. Sostituzione placeholder

Scarica o clona questa repository:

```bash
git clone https://github.com/lsarandrea/betterdesk-synology.git
cd betterdesk-synology
```

**Cerca e sostituisci** in **tutti i file** (compose, script, HTML) i seguenti placeholder con i tuoi valori:

| Placeholder | Valore da inserire | Esempio |
|-------------|-------------------|----------|
| `YOUR_DOMAIN` | Il tuo dominio pubblico | `rustdesk.miodominio.com` |
| `YOUR_ADMIN_EMAIL` | Email amministratore | `admin@miodominio.com` |
| `YOUR_ADMIN_PASSWORD` | Password sicura admin | `MySecureP@ssw0rd!` |
| `YOUR_NAS_VOLUME` | Path volume NAS | `/volume1` |

> ⚠️ **Attenzione:** `YOUR_PUBLIC_KEY` **NON** va sostituito ora — la chiave viene generata automaticamente al primo avvio (vedi step 5).

Puoi usare il comando `sed` per sostituire automaticamente (da Linux/macOS):

```bash
# Esempio per YOUR_DOMAIN
find . -type f -exec sed -i 's/YOUR_DOMAIN/rustdesk.miodominio.com/g' {} +
```

### 4. Deploy dei container

Copia il `docker-compose.yml` modificato sul NAS:

```bash
scp docker-compose.yml admin@nas-ip:/volume1/docker/betterdesk/
```

Via SSH sul NAS:

```bash
cd /volume1/docker/betterdesk
docker compose up -d
```

Verifica che tutti e 3 i container siano in running:

```bash
docker ps | grep betterdesk
```

### 5. Recupero chiave pubblica

Dopo il primo avvio, il server genera automaticamente la coppia di chiavi. Recuperala:

```bash
cat /volume1/docker/betterdesk/data/id_ed25519.pub
```

Esempio output:
```
nj060TuwSglo6mG29z0euthrkL6cpLu0TpjXMpzFs=
```

⚠️ **Ora sostituisci `YOUR_PUBLIC_KEY`** in tutti gli script di installazione client (`client-install/*.bat`, `*.sh`, `*.html`) con la chiave appena ottenuta.

### 6. Configurazione client

Ogni client RustDesk va configurato con:

- **ID/Relay Server:** `YOUR_DOMAIN` (il tuo dominio)
- **API Server:** `http://YOUR_DOMAIN:21121`
- **Chiave pubblica:** la chiave ottenuta al punto 5

Usa gli script automatici nella cartella `client-install/` (dopo aver sostituito i placeholder).

---

## 📝 Tabella completa placeholder

Di seguito l'elenco **file per file** di tutte le stringhe da sostituire.

### `docker-compose.yml`

| Stringa | Descrizione | Esempio |
|---------|-------------|----------|
| `YOUR_DOMAIN` | Dominio del server (8 occorrenze) | `rustdesk.miodominio.com` |
| `YOUR_ADMIN_EMAIL` | Email admin (1 occorrenza) | `admin@miodominio.com` |
| `YOUR_ADMIN_PASSWORD` | Password admin (1 occorrenza) | `MySecureP@ssw0rd!` |
| `YOUR_NAS_VOLUME` | Volume Synology (2 occorrenze) | `/volume1` |

### `client-install/index.html`

| Stringa | Descrizione | Dove appare |
|---------|-------------|-------------|
| `YOUR_DOMAIN` | Dominio server | Box footer "Server:" |
| `YOUR_PUBLIC_KEY` | Chiave pubblica | Box footer "Chiave:" |

### `client-install/install-rustdesk-windows.bat`

| Stringa | Occorrenze |
|---------|------------|
| `YOUR_DOMAIN` | 6 |
| `YOUR_PUBLIC_KEY` | 1 |

### `client-install/install-rustdesk-macos.sh`

| Stringa | Occorrenze |
|---------|------------|
| `YOUR_DOMAIN` | 6 |
| `YOUR_PUBLIC_KEY` | 1 |

### `client-install/install-rustdesk-linux.sh`

| Stringa | Occorrenze |
|---------|------------|
| `YOUR_DOMAIN` | 6 |
| `YOUR_PUBLIC_KEY` | 1 |

---

## Struttura della repository

```
betterdesk-synology/
├── docker-compose.yml              ← Configurazione Docker Compose (con placeholder)
├── README.md                       ← Questa guida
└── client-install/
    ├── index.html                  ← Pagina installazione client (con rilevamento OS)
    ├── install-rustdesk-windows.bat
    ├── install-rustdesk-macos.sh
    └── install-rustdesk-linux.sh
```

---

## Troubleshooting

### WARN "No public IP detected"
Falso positivo: il binario stampa questo avviso prima di leggere le variabili d'ambiente. Il relay funziona correttamente se i peer si connettono.

### Console non raggiunge l'API
Verifica che `BETTERDESK_API_URL` nel docker-compose punti a `http://127.0.0.1:21114/api` (non `localhost`, per evitare problemi IPv6).

### Peer non visibili nella rubrica
Nel client RustDesk admin, verifica che `API Server` sia impostato su `http://YOUR_DOMAIN:21121`.

### Container che crasha al riavvio
Assicurati di usare il flag `-relay-max-conns-ip` e NON `-registration-rate-limit` (quest'ultimo causa crash su alcune versioni del binario).

### Client non si connettono
1. Verifica che il port forwarding sia attivo per **tutte** le porte (21115-21119, 21121)
2. Controlla che il DNS punti correttamente all'IP pubblico
3. Verifica che la chiave pubblica nei client sia identica a quella del server

---

## Aggiornamento

Per aggiornare alle ultime immagini Docker:

```bash
cd /volume1/docker/betterdesk
docker compose pull
docker compose up -d
```

---

## Note tecniche

- Entrambi i container usano `network_mode: host` — necessario su Synology per il corretto binding delle porte
- Il relay server (`hbbr`) usa la stessa image del signal server (`hbbs`), lanciata con comando diverso
- La chiave pubblica del server si trova in `YOUR_NAS_VOLUME/docker/betterdesk/data/id_ed25519.pub`
- La console BetterDesk va sempre servita tramite reverse proxy HTTPS (per evitare problemi con WebSocket)

---

## Licenza

Questo template è rilasciato senza licenza specifica. I componenti utilizzati (RustDesk, BetterDesk) sono soggetti alle loro rispettive licenze.

---

## Contributi

PR e segnalazioni sono benvenute! Apri una issue se incontri problemi.
