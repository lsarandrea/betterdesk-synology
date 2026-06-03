# Guida Rapida Installazione — BetterDesk su Synology

Procedura step-by-step completa per installazione pulita.

---

## Prerequisiti checklist

- [ ] SSH abilitato su DSM
- [ ] Docker / Container Manager installato
- [ ] Dominio DNS configurato e puntante al NAS
- [ ] Certificato SSL attivo nel DSM
- [ ] Reverse proxy configurato (porta 443 → localhost:5000)
- [ ] Porte 21114-21119 e 21122 aperte nel firewall e router

---

## Step 1 — Crea struttura cartelle

```bash
mkdir -p /volume1/docker/betterdesk/server
mkdir -p /volume1/docker/betterdesk/console/appdata
```

## Step 2 — Imposta permessi

```bash
chown -R 10001:10001 /volume1/docker/betterdesk/server
chown -R 10001:10001 /volume1/docker/betterdesk/console
chmod 755 /volume1/docker/betterdesk/console/appdata
```

## Step 3 — Crea docker-compose.yml

```bash
cd /volume1/docker/betterdesk
```

Copia il contenuto da `docker-compose.yml` nel repository e adatta:
- `PUBLIC_IP` → IP pubblico del tuo NAS
- `RELAY_SERVERS` → il tuo dominio

## Step 4 — Pull immagini

```bash
docker pull ghcr.io/unitronix/betterdesk-server:latest
docker pull ghcr.io/unitronix/betterdesk-console:latest
```

## Step 5 — Avvio

```bash
docker compose up -d
```

## Step 6 — Recupera password iniziale admin

```bash
sleep 15
docker logs betterdesk-console 2>&1 | grep -i "password\|admin\|init\|created"
```

## Step 7 — Verifica

```bash
docker compose ps
curl -sf http://localhost:21114/api/health && echo "Server OK"
```

## Step 8 — Primo accesso

Apri `https://betterdesk.maganet.it` e accedi con le credenziali trovate al Step 6.

---

> Per problemi → vedi `TROUBLESHOOTING.md`  
> Per dettagli completi → vedi `README.md`
