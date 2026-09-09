# Sigurnosno izvješće skeniranja kontejnerskih slika

**Autor: Lovro Siprak**
**Alat:** Trivy (Aqua Security) · **Datum izrade izvješća:** lipanj 2026.

Pokriva ishode učenja **I2** (sigurno upravljanje slikama, skeniranje,
tagging/politika objave) i **I4** (sigurnosne provjere u CI/CD, quality gate).

> Napomena o ponovljivosti: konkretan broj ranjivosti ovisi o datumu jer se baza
> CVE-ova stalno ažurira. Ovo izvješće opisuje **metodologiju, politiku i način
> regeneriranja** te prikazuje rezultat zadnjeg lokalnog skeniranja. Svako novo
> skeniranje (lokalno ili u CI-u) proizvodi svjež nalaz po istoj politici.

---

## 1. Što se skenira

| Slika (artefakt) | Osnovna slika | Namjena |
|---|---|---|
| `ticketing-api` | `node:20-alpine` | REST API |
| `ticketing-frontend` | `node:20-alpine` | Web UI |
| `ticketing-worker` | `node:20-alpine` | Pozadinska obrada |
| (povučene) `postgres:16-alpine`, `redis:7-alpine` | – | Baza / queue |

Skeniraju se: ranjivosti OS paketa, ranjivosti Node.js (npm) ovisnosti te
pogrešne konfiguracije (`misconfig`).

## 2. Kako se skenira (naredbe za regeneriranje)

```bash
# Instalacija Trivyja (Linux/macOS): https://trivy.dev/latest/getting-started/
# Skeniranje pojedine slike (HIGH/CRITICAL, ignoriraj ono bez popravka):
trivy image --severity HIGH,CRITICAL --ignore-unfixed \
  ghcr.io/<OWNER>/ticketing-api:1.0.0

# Skeniranje izvornog koda i Dockerfilea (misconfig + ovisnosti):
trivy fs --scanners vuln,misconfig,secret .

# Generiranje SARIF izvješća (isto što radi CI):
trivy image --format sarif --output trivy-api.sarif \
  ghcr.io/<OWNER>/ticketing-api:1.0.0
```

## 3. Quality gate (CI/CD)

U `.github/workflows/ci.yml` Trivy se izvršava nakon builda, **prije** objave
slike u registar:

- `severity: HIGH,CRITICAL`, `exit-code: 1`, `ignore-unfixed: true`
- Ako Trivy pronađe HIGH/CRITICAL ranjivost koja **ima popravak**, build pada i
  slika se **ne objavljuje** (gate). SARIF nalaz se uvijek šalje u GitHub
  *Security* tab radi evidencije i praćenja.

Time je sigurnosna provjera ugrađena u tok isporuke, a ne naknadna ručna radnja.

## 4. Rezultat zadnjeg skeniranja

Sažetak (HIGH/CRITICAL, `--ignore-unfixed`):

| Slika | CRITICAL | HIGH | Status gatea |
|---|---|---|---|
| `ticketing-api` | 0 | 0 | ✅ prolaz |
| `ticketing-frontend` | 0 | 0 | ✅ prolaz |
| `ticketing-worker` | 0 | 0 | ✅ prolaz |

Razlog dobrog rezultata: korištenje **`alpine`** osnovne slike (mala napadna
površina), instalacija **samo produkcijskih** ovisnosti (`npm install --omit=dev`),
te `--ignore-unfixed` koji izdvaja ranjivosti za koje popravak još ne postoji
(za njih se vodi evidencija, ali ne ruše build).

> Ako buduće skeniranje prijavi novi CRITICAL/HIGH s popravkom, postupak je:
> (1) podigni verziju osnovne slike ili ovisnosti, (2) rebuild, (3) ponovno
> skeniranje dok gate ne prođe. Vidi i korektivne mjere u `RUNBOOK.md`.

## 5. Prakse sigurnosti pri izradi slika (hardening)

- **Multi-stage build** – alati za build ne završe u runtime slici.
- **Minimalna `alpine` slika** + samo produkcijske ovisnosti.
- **Non-root** korisnik (`USER node`, UID 1000); u Kubernetesu dodatno
  `runAsNonRoot`, `readOnlyRootFilesystem`, `drop ALL`, `seccomp: RuntimeDefault`.
- **`tini`** kao PID 1 za uredno gašenje (signali, zombie procesi).
- **`HEALTHCHECK`** ugrađen u sliku.
- **`.dockerignore`** sprječava curenje `.env`, `.git` i `node_modules` u sliku.

## 6. Tagging i politika objave slika

| Pravilo | Vrijednost |
|---|---|
| Registar | GitHub Container Registry (`ghcr.io/<OWNER>/ticketing-*`) |
| Nepromjenjivi tag | `:<git-sha>` (npr. `:a1b2c3d`) – jednoznačno veže sliku uz commit |
| Pokretni tagovi | `:main` (zadnje s glavne grane), `:vX.Y.Z` (release tag) |
| `latest` | **Ne koristi se** u produkciji (nejasno koja je verzija) |
| Uvjet objave | Slika se objavljuje **samo** ako prođe testovi i Trivy gate |
| Objava na PR-u | Ne – PR-ovi se grade i skeniraju, ali se **ne** objavljuju |

Ova politika osigurava da je svaka slika u registru ušla kroz iste sigurnosne
provjere i da se uvijek može povezati s točnim commitom (reproducibilnost,
revizija, lakši rollback na poznati `git-sha`).
