# Secure Event Ticketing Platform

**Autor: Lovro Siprak**
Projekt iz kolegija *Uvod u DevOps – DevSecOps*, Sveučilište Algebra Bernays, 2026.

Sigurna višeslojna aplikacija za prodaju ulaznica, isporučena kroz cijeli
DevOps/DevSecOps ciklus: lokalni razvoj (Docker/Podman Compose), CI/CD s
sigurnosnim skeniranjem te produkcijska orkestracija na Kubernetesu (manifesti
i Helm chart).

---

## Sadržaj repozitorija

| Putanja | Što je |
|---|---|
| `api/`, `frontend/`, `worker/` | Izvorni kod servisa (Node.js) + `Dockerfile` |
| `infra/postgres/init.sql` | Inicijalna shema baze |
| `compose.yaml` | **1. dio** – lokalni razvoj jednom naredbom |
| `.env.example` | Predložak environment varijabli i lokalnih tajni |
| `k8s/` | **2. dio** – Kubernetes manifesti (`kubectl apply -k k8s/`) |
| `helm/secure-event-ticketing/` | **2. dio** – Helm chart (parametrizirano) |
| `.github/workflows/ci.yml` | CI/CD: build, test, Trivy scan (gate), push |
| `docs/` | Dokumentacija, izvješća i runbook (vidi dolje) |

### Dokumentacija (`docs/`)

- `ARHITEKTURA.md` – arhitektura, servisi i međuservisna komunikacija (I1)
- `I1-kontejneri-vs-vm.md` – kritička usporedba kontejnera i VM pristupa (I1)
- `PRODUCTION_DEPLOY.md` – detaljne produkcijske upute (I6)
- `security/image-scan-report.md` – sigurnosno izvješće skeniranja slika (I2/I4)
- `RUNBOOK.md` – runbook za incidente i troubleshooting (I5)

---

## Arhitektura ukratko

```
            ┌────────────┐        ┌──────────────┐
  Browser → │  frontend  │ ─────→ │     api      │
            │ (Node:3000)│  HTTP  │ (Node:8080)  │
            └────────────┘        └──────┬───────┘
                                          │ lPush narudžbe
                                          ▼
                                    ┌──────────┐
                                    │  redis   │  (queue)
                                    └────┬─────┘
                                         │ brPop
                                  ┌──────▼──────┐     ┌────────────┐
                                  │   worker    │ ──→ │ postgres   │
                                  │  (Node)     │     │ (baza)     │
                                  └─────────────┘     └────────────┘
```

Servisi: **frontend** (web UI), **api** (REST + health), **worker** (obrada
queue poruka), **postgres** (trajna pohrana), **redis** (queue/cache).
Detalji u `docs/ARHITEKTURA.md`.

---

## 1. dio – Lokalni razvoj (brzi start)

> Potreban je **Docker Desktop** ILI **Podman**. Naredbe su gotovo identične.

```bash
# 1) Pripremi tajne (kopiraj predložak i po želji promijeni lozinku)
cp .env.example .env

# 2) Pokreni CIJELI stack jednom naredbom
docker compose up --build          # Docker
# podman compose up --build        # Podman (alternativa)
```

Aplikacija:

- Web UI: <http://localhost:3000>
- API:    <http://localhost:8080>

**Hot-reload** je uključen: servisi se grade iz `dev` targeta (nodemon), a
`src/` je montiran kao volume – promjene koda se primijene odmah, bez rebuilda.

### Brza validacija funkcionalnosti

```bash
curl http://localhost:8080/healthz     # {"status":"ok","service":"api"}
curl http://localhost:8080/readyz      # {"status":"ready"}  (baza + redis rade)
curl http://localhost:8080/events      # lista evenata

# Kupnja karte -> ide u Redis queue -> worker je upiše u Postgres
curl -X POST http://localhost:8080/tickets/purchase \
  -H "Content-Type: application/json" \
  -d '{"eventId":"evt-1001","customerEmail":"student@example.com","quantity":2}'

curl http://localhost:8080/tickets/orders   # obrađene narudžbe iz baze
```

### Gašenje

```bash
docker compose down        # zaustavi (podaci baze ostaju u volumeu)
docker compose down -v     # zaustavi I obriši podatke baze (čisti reset)
```

---

## 2. dio – Produkcija (Kubernetes / Helm)

Najkraći put (Helm):

```bash
helm upgrade --install ticketing helm/secure-event-ticketing \
  --namespace ticketing --create-namespace \
  --set image.owner=<TVOJ_GITHUB_USERNAME>
```

ili čistim manifestima:

```bash
kubectl apply -k k8s/
```

Potpune, detaljne upute (instalacija clustera, Ingress, hosts, rolling update,
rollback) nalaze se u `docs/PRODUCTION_DEPLOY.md`.

---

## Sigurnosni elementi (DevSecOps)

- Multi-stage build, minimalna `alpine` runtime slika, **non-root** korisnik
- Odvojeni **ConfigMap** i **Secret** (bez hardkodiranih lozinki u kodu)
- **Liveness/Readiness** probe i **resource requests/limits** za sve servise
- **ServiceAccount + RBAC** (least privilege), `automountServiceAccountToken: false`
- **NetworkPolicy** segmentacija prometa (default-deny + eksplicitni allow)
- **Trivy** skeniranje slika kao **quality gate** u CI-u (HIGH/CRITICAL ruše build)
- `readOnlyRootFilesystem`, `drop ALL capabilities`, `seccomp: RuntimeDefault`

Detalji skeniranja: `docs/security/image-scan-report.md`.
