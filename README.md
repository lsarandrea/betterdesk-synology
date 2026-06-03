# BetterDesk + RustDesk su Synology NAS

**Template generico** per il deploy di un server self-hosted di controllo remoto basato su **RustDesk** e **BetterDesk** su Synology NAS.

Questa repository **non contiene domini hardcoded** — tutti i valori specifici sono rappresentati da **placeholder** che vanno sostituiti con i tuoi dati reali.

> **Esempio reale già compilato:** vedi [`maganet/`](./maganet/) per una configurazione pronta per Synology DS925+ su `betterdesk.maganet.it`.

---

## 📋 Indice

- [Prerequisiti](#prerequisiti)
- [Architettura](#architettura)
- [Porte utilizzate](#porte-utilizzate)
- [🛠️ Installazione](#️-installazione)
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
- [🗺️ Roadmap](#️-roadmap)

---

## Prerequisiti

- **Synology NAS** con Docker/Container Manager installato
- **Dominio pubblico** che punta al tuo IP (es. `betterdesk.miodominio.com`)
- **Port forwarding** sul router per le porte 21115–21119 (TCP/UDP)
- **Reverse proxy** configurato in DSM: `https://tuo-dominio:443` → `localhost:5000`
- **Certificato SSL** valido (Let's Encrypt via DSM)

---

## Architettura

```
Client RustDesk (Windows / macOS / Linux)
        │
        ▼
YOUR_DOMAIN (Router → Synology NAS)
        │
        ├── betterdesk-server (mode: all)
        │     ├── hbbs  (Signal Server)   :21115, :21116, :21118
        │     └── hbbr  (Relay Server)    :21117, :21119
        └── betterdesk-console           :5000  → Reverse proxy HTTPS → :443
```

**Reverse proxy DSM:** `https://YOUR_DOMAIN:443` → `http://localhost:5000`

> ℹ️ Il container `server` usa il flag `-mode all` che avvia hbbs e hbbr in un unico processo,
> semplificando la gestione rispetto alla versione con due container separati.

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
| 5000  | TCP | Console web (interna, esposta tramite reverse proxy) |

> Tutte le porte **21115–21119** devono essere in **port forwarding** sul router (TCP e UDP dove applicabile).

---

## 🛠️ Installazione

### 1. Preparazione ambiente

Creare le cartelle dati sul NAS (via SSH):

```bash
mkdir -p /volume1/docker/betterdesk/server
mkdir -p /volume1/docker/betterdesk/console
```

> ⚠️ Sostituisci `/volume1` con il tuo volume reale se diverso.

### 2. Configurazione DNS e porte

1. **DNS:** Punta il tuo dominio (es. `betterdesk.tuodominio.com`) all'IP pubblico del router
2. **Port forwarding:** Configura il router per inoltrare le porte **21115–21119** all'IP del NAS
3. **Reverse proxy DSM:** In Pannello di controllo DSM → Reverse Proxy:
   - Origine: `https://YOUR_DOMAIN:443`
   - Destinazione: `http://localhost:5000`
4. **Certificato SSL:** Associa il certificato Let's Encrypt al dominio in DSM

### 3. Sostituzione placeholder

Clona la repository e sostituisci i placeholder:

```bash
git clone https://github.com/lsarandrea/betterdesk-synology.git
cd betterdesk-synology
```

Sostituisci in **tutti i file** (docker-compose.yml, scripts, HTML):

| Placeholder | Valore da inserire | Esempio |
|-------------|-------------------|----------|
| `YOUR_DOMAIN` | Il tuo dominio pubblico | `betterdesk.miodominio.com` |
| `YOUR_PUBLIC_IP` | IP pubblico del router | `1.2.3.4` |
| `YOUR_ADMIN_PASSWORD` | Password sicura admin | `MySecureP@ssw0rd!` |
| `YOUR_NAS_VOLUME` | Path volume NAS | `/volume1` |

> ⚠️ **Attenzione:** `YOUR_PUBLIC_KEY` **NON** va sostituito ora — viene generata automaticamente al primo avvio (vedi step 5).

Sostituzione automatica via `sed` (Linux/macOS):

```bash
find . -type f \( -name '*.yml' -o -name '*.sh' -o -name '*.bat' -o -name '*.html' \) \
  -exec sed -i 's/YOUR_DOMAIN/betterdesk.miodominio.com/g' {} +

find . -type f \( -name '*.yml' -o -name '*.sh' -o -name '*.bat' -o -name '*.html' \) \
  -exec sed -i 's/YOUR_PUBLIC_IP/1.2.3.4/g' {} +

find . -type f \( -name '*.yml' -o -name '*.sh' -o -name '*.bat' -o -name '*.html' \) \
  -exec sed -i 's/YOUR_ADMIN_PASSWORD/MySecureP@ssw0rd!/g' {} +

find . -type f \( -name '*.yml' -o -name '*.sh' -o -name '*.bat' -o -name '*.html' \) \
  -exec sed -i 's|YOUR_NAS_VOLUME|/volume1|g' {} +
```

### 4. Deploy dei container

Copia il `docker-compose.yml` sul NAS:

```bash
scp docker-compose.yml admin@<nas-ip>:/volume1/docker/betterdesk/
```

Via SSH sul NAS:

```bash
cd /volume1/docker/betterdesk
docker compose up -d
```

Verifica i container:

```bash
docker ps | grep betterdesk
```

### 5. Recupero chiave pubblica

Dopo il primo avvio, il server genera automaticamente la coppia di chiavi:

```bash
cat /volume1/docker/betterdesk/server/id_ed25519.pub
```

Esempio output:
```
nj060TuwSglo6mG29z0euthrkL6cpLu0TpjXMpzFs=
```

⚠️ **Ora sostituisci `YOUR_PUBLIC_KEY`** in tutti i file `client-install/` con la chiave ottenuta:

```bash
find client-install/ -type f \
  -exec sed -i 's/YOUR_PUBLIC_KEY/CHIAVE_OTTENUTA/g' {} +
```

### 6. Configurazione client

Ogni client RustDesk va configurato con:

- **ID/Relay Server:** `YOUR_DOMAIN`
- **API Server:** `http://YOUR_DOMAIN:21121`
- **Chiave pubblica:** la chiave ottenuta al punto 5

Usa gli script automatici nella cartella `client-install/` oppure ospita la pagina `client-install/index.html` su un sottodominio (es. `install.tuodominio.com`).

---

## 📝 Tabella completa placeholder

### `docker-compose.yml`

| Placeholder | Occorrenze | Descrizione |
|-------------|------------|-------------|
| `YOUR_DOMAIN` | 2 | Dominio pubblico del server |
| `YOUR_PUBLIC_IP` | 1 | IP pubblico del router |
| `YOUR_ADMIN_PASSWORD` | 1 | Password admin BetterDesk |
| `YOUR_NAS_VOLUME` | 4 | Path volume Synology |

### `client-install/index.html`

| Placeholder | Descrizione |
|-------------|-------------|
| `YOUR_DOMAIN` | Dominio server (box info) |
| `YOUR_PUBLIC_KEY` | Chiave pubblica (box info) |

### `client-install/install-rustdesk-*.sh` / `*.bat`

| Placeholder | Occorrenze |
|-------------|------------|
| `YOUR_DOMAIN` | 3–4 |
| `YOUR_PUBLIC_KEY` | 1 |

---

## Struttura della repository

```
betterdesk-synology/
├── docker-compose.yml              ← Template generico (con placeholder)
├── README.md                       ← Questa guida
├── client-install/
│   ├── index.html                  ← Pagina installazione client (template)
│   ├── install-rustdesk-windows.bat
│   ├── install-rustdesk-macos.sh
│   └── install-rustdesk-linux.sh
└── maganet/                        ← Configurazione specifica MaGa (esempio reale)
    ├── docker-compose.yml          ← Compose compilato per betterdesk.maganet.it
    ├── README.md                   ← Guida deploy MaGa
    └── client-install/
        ├── index.html              ← Pagina install.maganet.it
        ├── install-rustdesk-windows.bat
        ├── install-rustdesk-macos.sh
        └── install-rustdesk-linux.sh
```

---

## Troubleshooting

### WARN "No public IP detected"
Falso positivo: il binario stampa questo avviso prima di leggere le variabili d'ambiente. Il relay funziona correttamente se i peer si connettono.

### Console non raggiunge l'API
Verifica che `BETTERDESK_API_URL` nel docker-compose punti a `http://localhost:21114/api` (con `NODE_OPTIONS=--dns-result-order=ipv4first` per evitare problemi IPv6).

### Peer non visibili nella rubrica
Nel client RustDesk, verifica che `API Server` sia impostato su `http://YOUR_DOMAIN:21121`.

### Container che crasha al riavvio
Verifica che il volume `/opt/rustdesk` abbia i permessi corretti:
```bash
chown -R 1000:1000 /volume1/docker/betterdesk/server
```

### Client non si connettono
1. Verifica che il port forwarding sia attivo per **tutte** le porte (21115–21119)
2. Controlla che il DNS punti correttamente all'IP pubblico
3. Verifica che la chiave pubblica nei client sia identica a quella del server

---

## Aggiornamento

```bash
cd /volume1/docker/betterdesk
docker compose pull
docker compose up -d
```

---

## 🗺️ Roadmap

### ✅ Completato
- [x] Deploy BetterDesk + RustDesk su NAS personale (`betterdesk.arancio.me`)
- [x] Template generico con placeholder pubblicato su GitHub
- [x] Pagina installazione client multi-OS (`install.arancio.me`)
- [x] Deploy BetterDesk + RustDesk su MaGaServer1 (`betterdesk.maganet.it`)
- [x] Pagina installazione client con branding MaGa (`install.maganet.it`)
- [x] Repository ristrutturata con cartella `maganet/` come esempio reale

### 🔧 In sviluppo
- [ ] **Branding MaGa in BetterDesk Console** — personalizzazione logo, nome e colori nell'interfaccia web di BetterDesk per `betterdesk.maganet.it`:
  - [ ] Sostituire logo e favicon di default con il logo MaGa
  - [ ] Modificare il titolo dell'applicazione da "BetterDesk" a "MaGa Remote"
  - [ ] Adattare la palette colori (giallo/oro `#d4a017` come accent primario)
  - [ ] Personalizzare la pagina di login con header MaGa
  - [ ] Indagare se BetterDesk supporta custom branding via variabili d'ambiente o file di config
- [ ] **Dominio install.maganet.it** — configurare reverse proxy DSM per servire i file statici `maganet/client-install/`
- [ ] **Script bash one-shot** — script che sostituisce tutti i placeholder automaticamente chiedendo i valori in input

### 💡 Idee future
- [ ] Aggiungere supporto `.env` file per separare i segreti dal compose
- [ ] Supporto Traefik come reverse proxy alternativo a DSM
- [ ] Pagina installazione client con rilevamento automatico OS via JavaScript
- [ ] Notifiche Telegram/email alla prima connessione di un nuovo dispositivo
- [ ] Guida per deploy su altri NAS (QNAP, TrueNAS)

---

## Note tecniche

- Entrambi i container usano `network_mode: host` — necessario su Synology per il corretto binding delle porte
- Il container `server` usa il flag `-mode all` (hbbs + hbbr in un unico processo)
- La chiave pubblica del server si trova in `YOUR_NAS_VOLUME/docker/betterdesk/server/id_ed25519.pub`
- La console BetterDesk va sempre servita tramite reverse proxy HTTPS (richiesto per WebSocket)

---

## Licenza

Questo template è rilasciato senza licenza specifica. I componenti utilizzati (RustDesk, BetterDesk) sono soggetti alle loro rispettive licenze.

---

## Contributi

PR e segnalazioni sono benvenute! Apri una issue se incontri problemi o vuoi contribuire.
