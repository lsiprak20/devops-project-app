# Arhitektura – Secure Event Ticketing Platform

**Autor: Lovro Siprak**

Ovaj dokument pokriva ishod učenja **I1** (procjena upotrebe kontejnera i
servisa, odabir servisa i njihovih uloga, arhitektura i međuservisna
komunikacija, usklađenost s ciljevima).

## 1. Pregled

Aplikacija je sustav za prodaju ulaznica za evente. Sastoji se od pet servisa
koji su namjerno razdvojeni po odgovornosti (separation of concerns), što
omogućuje neovisno skaliranje, deploy i održavanje svakog dijela.

```
                          Internet / korisnik
                                  │
                                  ▼
                         ┌─────────────────┐
                         │  Ingress (nginx)│   host: ticketing.local
                         │   / → frontend  │
                         │ /api → api      │
                         └───────┬─────────┘
                 ┌───────────────┴───────────────┐
                 ▼                                ▼
          ┌────────────┐                   ┌────────────┐
          │  frontend  │   GET /events     │    api     │
          │  Node 3000 │ ────────────────→ │  Node 8080 │
          │  (web UI)  │   POST /tickets   │ (REST API) │
          └────────────┘                   └─────┬──────┘
                                                  │ LPUSH (narudžba)
                                                  ▼
                                            ┌──────────┐
                                            │  redis   │  queue: ticket_orders
                                            └────┬─────┘
                                                 │ BRPOP (blokirajuće)
                                          ┌──────▼──────┐
                                          │   worker    │  pozadinska obrada
                                          └──────┬──────┘
                                                 │ INSERT
                                                 ▼
                                           ┌────────────┐
                                           │  postgres  │  trajna pohrana
                                           └────────────┘
```

## 2. Servisi i njihove uloge

| Servis | Tehnologija | Uloga | Stanje |
|---|---|---|---|
| **frontend** | Node.js + Express | Statički web UI; servira HTML i `/config`; preusmjerava preglednik na API | bez stanja (stateless) |
| **api** | Node.js + Express | REST API: `/events`, `/tickets/purchase`, `/healthz`, `/readyz`; stavlja narudžbe u Redis queue | bez stanja |
| **worker** | Node.js | Čita narudžbe iz Redis queuea (`BRPOP`) i upisuje ih u Postgres | bez stanja |
| **postgres** | PostgreSQL 16 | Trajna pohrana narudžbi | **sa stanjem** (PVC) |
| **redis** | Redis 7 | Queue/cache između API-ja i workera | efemerno |

### Zašto baš ovakva podjela

- **Razdvajanje zapisa i obrade.** API ne piše izravno u bazu; narudžbu samo
  stavi u queue i odmah vrati `202 Accepted`. To čini API brzim i otpornim na
  nagle navale prometa (npr. prodaja popularnog koncerta) – queue apsorbira
  vrhove, a worker obrađuje svojim tempom.
- **Neovisno skaliranje.** Ako obrada postane usko grlo, skalira se samo
  `worker`. Ako je usko grlo dohvat evenata, skalira se samo `api`.
- **Otpornost.** Ako worker ili baza nakratko padnu, narudžbe ostaju u Redisu i
  obrade se kad se servis vrati (vidi i `RUNBOOK.md`).

## 3. Međuservisna komunikacija

- **Browser → frontend**: HTTP, kroz Ingress na `/`.
- **Browser → api**: HTTP, kroz Ingress na `/api` (API u kodu sam skida `/api`
  prefiks). CORS je dopušten na API-ju.
- **api → redis**: `LPUSH` narudžbe u listu `ticket_orders`.
- **worker → redis**: `BRPOP` (blokirajuće čitanje) iste liste.
- **api/worker → postgres**: SQL preko `pg` poola (api čita narudžbe, worker piše).

Servisi se međusobno pronalaze preko **Kubernetes DNS-a** (npr. host `postgres`,
`redis`, `api`) odnosno preko imena servisa u Compose mreži lokalno. Nigdje nema
hardkodiranih IP adresa.

## 4. Usklađenost s ciljevima projekta

| Cilj projekta | Kako je postignut |
|---|---|
| Sigurna isporuka | Trivy gate u CI-u, non-root, hardened SecurityContext |
| Upravljanje slikama | Multi-stage build, tagging po git SHA, ghcr registry |
| Orkestracija | Kubernetes/Helm, probe, resursi, rolling update/rollback |
| Observability | Health/ready endpointi, probe, `kubectl logs`, status narudžbi |
| Troubleshooting | Runbook s realnim incidentnim scenarijima (`RUNBOOK.md`) |
