# BetterDesk — Troubleshooting Guide

> Problemi reali incontrati durante l'installazione su **betterdesk.arancio.me**  
> Usare questa guida come riferimento preventivo prima di ogni nuova installazione.

---

## ❌ Problema 1: `hostname` incompatibile con `network_mode: service:`

**Errore:**
```
Error response from daemon: conflicting options: hostname and the network mode
```

**Causa:** Quando si usa `network_mode: service:<nome>` sul container `console`, Docker non permette di impostare anche il campo `hostname`.

**Soluzione:** Rimuovere la riga `hostname` dal container `console`. Il campo `hostname` è ammesso **solo** sul container `server`.

```yaml
console:
  # hostname: betterdesk-console  ← VA RIMOSSO
  network_mode: service:server
```

---

## ❌ Problema 2: Console non si connette al server — IPv4 vs IPv6

**Errore nei log console:**
```
DeviceStatus: Go event bus error: connect ECONNREFUSED 127.0.0.1:21114
```

**Causa:** Node.js di default risolve `localhost` in IPv6 (`::1`), ma il server Go di BetterDesk ascolta solo su IPv4 (`127.0.0.1`). La variabile `BETTERDESK_API_URL=http://localhost:21114/api` viene ignorata — la console ha l'URL hardcoded.

**Soluzione:** Aggiungere al container `console`:
```yaml
environment:
  - NODE_OPTIONS=--dns-result-order=ipv4first
```
Questo forza Node.js a preferire IPv4 quando risolve `localhost`, quindi la connessione va su `127.0.0.1:21114`.

---

## ❌ Problema 3: Relay usa IP interno Docker invece dell'IP pubblico

**Errore nei log server:**
```
WARN: No public IP detected, using LAN IP 172.27.0.2
WARN: Remote relay connections will fail!
```

**Causa:** Il server non conosce l'IP pubblico e usa l'IP interno del container Docker come relay. I client fuori LAN non riescono a connettersi.

**Soluzione:** Aggiungere al container `server`:
```yaml
environment:
  - PUBLIC_IP=<IP_PUBBLICO_O_HOSTNAME>
  - RELAY_SERVERS=<hostname>:21117
```

Esempio per MaGa:
```yaml
  - PUBLIC_IP=betterdesk.maganet.it
  - RELAY_SERVERS=betterdesk.maganet.it:21117
```

---

## ❌ Problema 4: Rate limiting blocca la registrazione dei client

**Errore nei log server:**
```
Rate limited registration from 172.27.0.1
Security modules initialized: blocklist=0 entries, rate-limit=20/min
```

**Causa:** I client RustDesk tentano di ri-registrarsi in loop dopo un errore, finendo nel rate limit del server (default: 20 tentativi/min).

**Soluzione temporanea:** Riavviare i client RustDesk sui PC — azzera il loop.

**Soluzione permanente nel compose:**
```yaml
environment:
  - REGISTRATIONS_PER_MIN=300
```
> ⚠️ Verifica che la versione dell'immagine in uso supporti questa variabile.

---

## ❌ Problema 5: Container con nome anomalo dopo riavvio da GUI

**Sintomo:** Container Manager mostra un container con nome tipo `0a5815c54abf/betterdesk-console` e nessuna operazione GUI funziona.

**Causa:** Docker Compose non riesce ad assegnare il `container_name` specificato perché esiste un conflitto. L'interfaccia grafica va in stato inconsistente.

**Soluzione via SSH:**
```bash
cd /volume1/docker/betterdesk
docker compose down --remove-orphans
docker compose up -d
```
Il flag `--remove-orphans` rimuove tutti i container orfani del progetto, inclusi quelli con nomi anomali. Dopo, ricarica la pagina del browser (F5) sul Container Manager.

---

## ❌ Problema 6: `INIT_ADMIN_PASS` ignorata — password generata automaticamente

**Sintomo:** Dopo il primo avvio, le credenziali inserite nel compose non funzionano.

**Causa:** Se nel database esiste già un utente admin (da un avvio precedente), la console ignora `INIT_ADMIN_PASS` e mantiene la password esistente. Se il DB è nuovo, genera una password casuale e la logga.

**Come trovare la password generata:**
```bash
docker logs betterdesk-console | grep -i "admin password"
# Output esempio:
# Generated admin password: 085fe82360ed899199a118d3cdebe223
```

**Best practice:** Dopo il primo accesso, cambiare subito la password dal profilo nella console web.

---

## ❌ Problema 7: Container `betterdesk-server` in stato `Exited 137`

**Causa:** Il processo è stato killato (OOM killer o `docker stop` forzato da GUI durante operazioni precedenti).

**Soluzione:**
```bash
cd /volume1/docker/betterdesk
docker compose down --remove-orphans
docker compose up -d
docker ps | grep betterdesk
```

---

## ❌ Problema 8: `permission denied` su `/var/run/docker.sock`

**Sintomo:**
```
permission denied while trying to connect to the Docker daemon socket
```

**Causa:** L'utente SSH in uso non è `root` e non ha accesso al socket Docker di Synology.

**Soluzione:** Connettersi come `root`:
```bash
ssh root@<IP_NAS>
# oppure da utente normale:
sudo -i
```

---

## ✅ Checklist pre-avvio (nuova installazione)

- [ ] Creare le cartelle: `mkdir -p /volume1/docker/betterdesk/{server,console}`
- [ ] Impostare permessi: `chown -R root:root /volume1/docker/betterdesk && chmod -R 755 /volume1/docker/betterdesk`
- [ ] Verificare che `hostname` NON sia presente nel container `console` se si usa `network_mode: service:server`
- [ ] Aggiungere `NODE_OPTIONS=--dns-result-order=ipv4first` al container `console`
- [ ] Aggiungere `PUBLIC_IP` e `RELAY_SERVERS` al container `server` con hostname/IP pubblico
- [ ] Aggiungere `DB_URL` al container `server`
- [ ] Verificare DNS: il dominio deve puntare all'IP pubblico del server
- [ ] Verificare il reverse proxy su Synology Application Portal
- [ ] Aprire le porte sul router: TCP 21115-21119, UDP 21116

---

## 🔍 Comandi di diagnostica utili

```bash
# Stato container
docker ps | grep betterdesk

# Log in tempo reale
docker logs betterdesk-server --tail 30 -f
docker logs betterdesk-console --tail 30 -f

# Verificare che il server risponda sull'API
docker exec betterdesk-server curl -s http://127.0.0.1:21114/api/health
# Risposta attesa: {"peers_online":X,"peers_total":Y,"status":"ok",...}

# Verificare porte in ascolto sull'host
ss -tlnp | grep 2111

# Pulizia completa e riavvio
cd /volume1/docker/betterdesk
docker compose down --remove-orphans
docker compose up -d

# Leggere la chiave pubblica (da distribuire ai client)
cat /volume1/docker/betterdesk/server/id_ed25519.pub

# Leggere l'API key (per BetterDesk Agent)
cat /volume1/docker/betterdesk/server/.api_key
```

---

## 📋 Architettura finale funzionante

```
[Client RustDesk] ──TCP 21115-21119──▶ [betterdesk-server]
                                              │
                                    network_mode: service:server
                                              │
                                       [betterdesk-console]
                                              │
                              [Reverse Proxy Synology]
                                              │
                         https://betterdesk.<dominio> → porta 5000
```

La console condivide il network namespace del server tramite `network_mode: service:server`, quindi comunica con il server Go su `127.0.0.1:21114` (stesso stack di rete).
