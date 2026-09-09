# 📘 Upute za deploy – KORAK PO KORAK (za potpune početnike)

**Autor: Lovro Siprak**

Ovaj vodič pretpostavlja da **ne znaš ništa** o Dockeru i Kubernetesu i vodi te
od instalacije alata do aplikacije koja radi — prvo lokalno (1. dio projekta), a
zatim na Kubernetesu (2. dio projekta). Prati korake **redom**. Gdje god vidiš
okvir s naredbom, kopiraj je u terminal i pritisni Enter.

> Pojmovi na 30 sekundi:
> - **Kontejner** = zapakirana aplikacija sa svime što joj treba.
> - **Slika (image)** = "kalup" iz kojeg se kontejner pokreće.
> - **Docker/Podman** = alat koji pokreće kontejnere na tvom računalu.
> - **Kubernetes** = "dirigent" koji pokreće puno kontejnera u produkciji.
> - **Terminal** = aplikacija u koju upisuješ naredbe (Windows: *PowerShell*;
>   macOS: *Terminal*).

---

## DIO 0 — Što ti treba instalirati (jednom)

### Korak 0.1 — Instaliraj Docker Desktop

1. Idi na <https://www.docker.com/products/docker-desktop/> i preuzmi verziju za
   svoj OS (Windows/Mac).
2. Instaliraj, **pokreni Docker Desktop** i pričekaj da u donjem lijevom kutu
   ikona kita postane zelena ("Engine running").
3. Provjeri u terminalu da radi:
   ```bash
   docker --version
   docker compose version
   ```
   Ako ispiše brojeve verzija — odlično.

> 💡 Koristiš **Podman** umjesto Dockera? Sve naredbe ispod rade isto, samo
> umjesto `docker` napiši `podman`, a umjesto `docker compose` → `podman compose`.

### Korak 0.2 — (za 2. dio) Uključi Kubernetes u Docker Desktopu

1. Otvori Docker Desktop → **Settings (zupčanik)** → **Kubernetes**.
2. Označi **Enable Kubernetes** → **Apply & Restart**. Pričekaj 2–5 min da
   ikona Kubernetesa postane zelena.
3. Instaliraj `kubectl` i `helm` (ako ih već nemaš):
   - **Windows (PowerShell kao administrator):**
     ```powershell
     winget install -e --id Kubernetes.kubectl
     winget install -e --id Helm.Helm
     ```
   - **macOS (Homebrew):**
     ```bash
     brew install kubectl helm
     ```
4. Provjeri:
   ```bash
   kubectl version --client
   helm version
   kubectl get nodes      # treba pisati jedan node u stanju Ready
   ```

> Ne moraš sve instalirati odjednom. Za **DIO 1** treba ti samo Docker. Za
> **DIO 2** treba ti i Kubernetes + kubectl + helm.

---

## DIO 1 — Pokreni aplikaciju LOKALNO (1. dio projekta)

### Korak 1.1 — Otvori projekt u terminalu

Uđi u mapu projekta (ondje gdje je datoteka `compose.yaml`):
```bash
cd putanja/do/secure-event-ticketing
```
> Na Windowsu možeš u File Exploreru otvoriti mapu, kliknuti u adresnu traku,
> upisati `powershell` i Enter — otvori se terminal već u toj mapi.

### Korak 1.2 — Napravi `.env` datoteku (tajne)

```bash
cp .env.example .env        # Windows PowerShell: copy .env.example .env
```
Time si stvorio datoteku `.env` s lozinkama za lokalni rad. Ne moraš ništa
mijenjati za lokalno testiranje (ali smiješ promijeniti `POSTGRES_PASSWORD`).

### Korak 1.3 — Pokreni CIJELI sustav jednom naredbom

```bash
docker compose up --build
```
Što se događa: Docker gradi slike za `api`, `frontend` i `worker`, povlači
`postgres` i `redis`, i sve poveže. **Prvi put traje par minuta** (skida i
gradi). Vidjet ćeš puno teksta — to je normalno. Kad se smiri i vidiš retke
poput `API listening on port 8080` i `Frontend listening on port 3000`, radi.

> Ostavi ovaj terminal otvoren — tu teku logovi. Za sljedeće naredbe otvori
> **drugi** terminal (u istoj mapi).

### Korak 1.4 — Provjeri da radi (web)

Otvori preglednik na: **<http://localhost:3000>**
Vidjet ćeš stranicu "Secure Event Ticketing Platform". Odaberi event, klikni
**Purchase** — u "Output" okviru pojavi se potvrda s `orderId`.

### Korak 1.5 — Provjeri da radi (terminal / API)

U drugom terminalu:
```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
curl http://localhost:8080/events

curl -X POST http://localhost:8080/tickets/purchase ^
  -H "Content-Type: application/json" ^
  -d "{\"eventId\":\"evt-1001\",\"customerEmail\":\"student@example.com\",\"quantity\":2}"

curl http://localhost:8080/tickets/orders
```
> Gornji `^` i navodnici su za **Windows PowerShell/CMD**. Na **macOS/Linux**
> koristi `\` za prelazak u novi red i jednostruke navodnike kao u `README.md`.

Tok koji si upravo testirao: API je narudžbu stavio u Redis → worker ju je
pokupio → upisao u PostgreSQL → `/tickets/orders` ju vraća. 🎉

### Korak 1.6 — Hot-reload (nije obavezno)

Promijeni nešto u `api/src/server.js` i spremi — worker/api se automatski
restarta (nodemon) bez ponovnog `up --build`.

### Korak 1.7 — Gašenje

U terminalu s logovima pritisni `Ctrl + C`, zatim:
```bash
docker compose down        # ugasi sve (podaci baze ostaju)
docker compose down -v     # ugasi I obriši podatke (čisti reset)
```

✅ **DIO 1 gotov.** Za predaju 1. dijela ovo je dovoljno: `Dockerfile`-ovi,
`compose.yaml`, `.env.example`, ovaj README i validacija iznad.

---

## DIO 2 — Deploy na KUBERNETES (2. dio projekta)

Imaš **dva načina**. Preporučam **Način A (Helm)**. Oba pretpostavljaju da je
Kubernetes upaljen (Korak 0.2).

### Korak 2.1 — Instaliraj Ingress kontroler (jednom)

Ingress je "ulazna vrata" prometa u cluster.
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```
Pričekaj da bude spreman:
```bash
kubectl get pods -n ingress-nginx     # čekaj da controller bude Running/Completed
```

### Korak 2.2 — Dostavi slike clusteru

Kubernetes treba slike aplikacije. Najlakše lokalno:

```bash
# Izgradi produkcijske slike (target runtime) iz korijena projekta:
docker build -t ticketing-api:1.0.0      ./api
docker build -t ticketing-frontend:1.0.0 ./frontend
docker build -t ticketing-worker:1.0.0   ./worker
```

- **Docker Desktop Kubernetes:** gotovo — koristi lokalne slike izravno.
- **minikube:** dodatno učitaj slike u cluster:
  ```bash
  minikube image load ticketing-api:1.0.0
  minikube image load ticketing-frontend:1.0.0
  minikube image load ticketing-worker:1.0.0
  ```
- **kind:**
  ```bash
  kind load docker-image ticketing-api:1.0.0 ticketing-frontend:1.0.0 ticketing-worker:1.0.0
  ```

> Ako lokalno gradiš slike s tagom `ticketing-*:1.0.0`, pri Helm/kubectl deployu
> postavi da koristi baš njih (vidi napomene u koracima ispod).

### Korak 2.3 — NAČIN A: Deploy preko Helma (preporuka)

Da koristiš lokalno izgrađene slike (`ticketing-*:1.0.0`), postavi prazan
registry/owner i tag `1.0.0`:
```bash
helm upgrade --install ticketing helm/secure-event-ticketing \
  --namespace ticketing --create-namespace \
  --set image.registry="" \
  --set image.owner="library" \
  --set image.tag="1.0.0" \
  --set secret.postgresPassword="JakaLozinka_2026!"
```
> Helper slaže ime kao `registry/owner/ticketing-<servis>:tag`. Za lokalne slike
> ime mora ispasti `ticketing-api:1.0.0`. Ako gornje ne pogodi točno ime, vidi
> **Način B** koji je za lokalne slike još jednostavniji.

Provjeri:
```bash
kubectl get pods -n ticketing -w     # gledaj kako svi prelaze u Running / Ready
```

### Korak 2.3b — NAČIN B: Deploy preko gotovih manifesta (najjednostavnije lokalno)

1. U datotekama `k8s/06-api.yaml`, `k8s/07-worker.yaml`, `k8s/08-frontend.yaml`
   zamijeni `ghcr.io/<OWNER>/ticketing-<servis>:1.0.0` s lokalnim imenom
   `ticketing-<servis>:1.0.0`. (`imagePullPolicy: IfNotPresent` je već postavljen.)
   Brza zamjena:
   - **macOS/Linux:**
     ```bash
     sed -i '' 's#ghcr.io/<OWNER>/##g' k8s/06-api.yaml k8s/07-worker.yaml k8s/08-frontend.yaml
     ```
   - **Linux (GNU sed):** isto, bez `''` nakon `-i`.
2. Deploy sve odjednom:
   ```bash
   kubectl apply -k k8s/
   ```
3. Provjeri:
   ```bash
   kubectl get pods,svc,ingress -n ticketing
   ```

### Korak 2.4 — Omogući pristup preko preglednika

Dodaj u **hosts** datoteku redak `127.0.0.1  ticketing.local`:
- **Windows:** otvori *Notepad kao administrator* → File → Open →
  `C:\Windows\System32\drivers\etc\hosts` → dodaj redak → spremi.
- **macOS/Linux:**
  ```bash
  echo "127.0.0.1  ticketing.local" | sudo tee -a /etc/hosts
  ```

Otvori: **<http://ticketing.local>**

> Ako se ne otvara, kao zamjena radi i port-forward (bez hosts/Ingressa):
> ```bash
> kubectl port-forward svc/frontend 3000:3000 -n ticketing
> kubectl port-forward svc/api 8080:8080 -n ticketing   # u drugom terminalu
> ```
> pa otvori <http://localhost:3000>.

### Korak 2.5 — Provjeri zdravlje

```bash
kubectl get pods -n ticketing
```
Svi redovi trebaju biti `Running` i `READY` oblika `n/n` (npr. `2/2`, `1/1`).
Ako neki nije — pogledaj `docs/RUNBOOK.md` (rješava 3 najčešća kvara).

### Korak 2.6 — Demonstracija ROLLING UPDATE (za bodove I6)

Simuliraj novu verziju:
```bash
# Helm:
helm upgrade ticketing helm/secure-event-ticketing --reuse-values --set image.tag=1.0.1
# ili kubectl:
kubectl set image deploy/api api=ticketing-api:1.0.1 -n ticketing
kubectl rollout status deploy/api -n ticketing
```
Zbog `maxUnavailable: 0` nema prekida rada tijekom zamjene.

### Korak 2.7 — Demonstracija ROLLBACK (za bodove I6)

```bash
# Helm:
helm history ticketing -n ticketing
helm rollback ticketing 1 -n ticketing
# ili kubectl:
kubectl rollout undo deploy/api -n ticketing
kubectl rollout status deploy/api -n ticketing
```

### Korak 2.8 — Čišćenje (kad završiš)

```bash
helm uninstall ticketing -n ticketing      # ako si koristio Helm
kubectl delete -k k8s/                      # ako si koristio manifeste
kubectl delete namespace ticketing
```

---

## DIO 3 — CI/CD i predaja na GitHub

1. Stvori repozitorij na GitHubu i pushaj cijeli projekt:
   ```bash
   git init
   git add .
   git commit -m "Secure Event Ticketing Platform - Lovro Siprak"
   git branch -M main
   git remote add origin https://github.com/<TVOJ_USERNAME>/secure-event-ticketing.git
   git push -u origin main
   ```
2. Otvaranjem repozitorija pokreće se **GitHub Actions** pipeline
   (`.github/workflows/ci.yml`): testira kod, gradi slike, **skenira Trivyjem**
   (HIGH/CRITICAL ruše build) i objavljuje slike u `ghcr.io`.
3. Rezultate vidiš u tabu **Actions**, a sigurnosne nalaze u tabu **Security**.

> Slike u `ghcr.io` su po defaultu privatne. Da ih cluster može povući, ili ih
> postavi na *public* (Packages → package → Settings), ili dodaj imagePullSecret.
> Za predaju projekta lokalni build (DIO 2) je sasvim dovoljan.

---

## ✅ Checklist predaje (mapiranje na tražene artefakte)

- [x] Izvorni kod svih servisa — `api/`, `frontend/`, `worker/`
- [x] `Dockerfile` za svaki servis — multi-stage, non-root
- [x] Compose datoteka (1. dio) — `compose.yaml` + `.env.example`
- [x] Kubernetes manifesti **i** Helm chart (2. dio) — `k8s/`, `helm/`
- [x] Dokumentacija lokalno + produkcija — `README.md`, `docs/PRODUCTION_DEPLOY.md`, ovaj vodič
- [x] Sigurnosno izvješće skeniranja — `docs/security/image-scan-report.md`
- [x] Runbook za troubleshooting — `docs/RUNBOOK.md`
- [x] CI/CD s sigurnosnim gateom — `.github/workflows/ci.yml`
- [x] Usporedba kontejnera i VM (I1) — `docs/I1-kontejneri-vs-vm.md`

Ako nešto zapne, prvo pogledaj `docs/RUNBOOK.md`. Sretno! — *Lovro Siprak*
