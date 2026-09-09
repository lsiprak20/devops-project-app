# Produkcijski deployment (Kubernetes / Helm)

**Autor: Lovro Siprak**

Pokriva ishod učenja **I6** (orkestracija, probe/resursi, Ingress, secrets/RBAC/
NetworkPolicy, rolling update i rollback).

## 1. Preduvjeti

- Kubernetes cluster (Docker Desktop K8s, minikube, kind ili pravi cluster)
- `kubectl` i (za Helm put) `helm`
- Ingress kontroler **ingress-nginx** instaliran
- Objavljene slike u `ghcr.io/<OWNER>/ticketing-*` **ili** lokalno izgrađene
  slike učitane u cluster

## 2. Dvije opcije deploya

### A) Helm (preporuka)

```bash
helm upgrade --install ticketing helm/secure-event-ticketing \
  --namespace ticketing --create-namespace \
  --set image.owner=<OWNER> \
  --set image.tag=1.0.0 \
  --set secret.postgresPassword='JakaLozinka_2026!'
```

Provjera renderiranog YAML-a bez instalacije:
```bash
helm template ticketing helm/secure-event-ticketing --set image.owner=<OWNER> | less
helm lint helm/secure-event-ticketing
```

### B) Čisti manifesti (kustomize)

```bash
# Prvo u k8s/06,07,08-*.yaml zamijeni <OWNER> svojim GitHub usernameom
kubectl apply -k k8s/
```

## 3. Konfiguracija i tajne (bez hardkodiranja)

- **ConfigMap** `ticketing-config` – ne-tajne vrijednosti (hostovi, portovi, imena).
- **Secret** `ticketing-secret` – `POSTGRES_USER`, `POSTGRES_PASSWORD`.
- U produkciji lozinku postavi preko `--set secret.postgresPassword=...` ili,
  bolje, preko **Sealed Secrets / External Secrets / Vault**. Lozinka nije u kodu.

## 4. Probe i resursi

- **api / frontend**: HTTP `readinessProbe` (`/readyz`, `/healthz`) i
  `livenessProbe` (`/healthz`).
- **postgres / redis**: `exec` probe (`pg_isready`, `redis-cli ping`).
- **worker**: `exec` liveness (`pgrep -f worker.js`).
- Svi servisi imaju `requests` i `limits` za CPU i memoriju (vidi `values.yaml`).

## 5. Vanjski pristup (Ingress)

`ticketing-ingress` (klasa `nginx`) usmjerava:
- `/` → `frontend:3000`
- `/api` → `api:8080` (API sam skida `/api` prefiks)

Dodaj u hosts datoteku reda radi:
```
127.0.0.1   ticketing.local
```
Pa otvori <http://ticketing.local>.

## 6. Sigurnost (least privilege + segmentacija)

- **ServiceAccount** `ticketing-sa`, `automountServiceAccountToken: false`,
  minimalna **Role** (samo čitanje ConfigMapa).
- **NetworkPolicy**: default-deny ingress + eksplicitni allow (api/worker→postgres,
  api/worker→redis, frontend/ingress→api, ingress→frontend).
  > Provodi ih CNI (Calico/Cilium). Na minikube: `minikube start --cni=calico`.
- **SecurityContext**: `runAsNonRoot`, `readOnlyRootFilesystem`, `drop ALL`,
  `seccompProfile: RuntimeDefault`.

## 7. Rolling update

Nova verzija (npr. novi git SHA):
```bash
# Helm
helm upgrade ticketing helm/secure-event-ticketing --set image.tag=<novi-sha>
# kubectl
kubectl set image deploy/api api=ghcr.io/<OWNER>/ticketing-api:<novi-sha> -n ticketing
kubectl rollout status deploy/api -n ticketing
```
`maxUnavailable: 0, maxSurge: 1` → novi pod se digne i postane Ready prije nego
se stari ugasi → **nula downtimea**.

## 8. Rollback

```bash
# Helm
helm history ticketing -n ticketing
helm rollback ticketing <REVIZIJA> -n ticketing
# kubectl
kubectl rollout undo deploy/api -n ticketing
kubectl rollout status deploy/api -n ticketing
```

## 9. Provjera zdravlja deploya

```bash
kubectl get pods,svc,ingress -n ticketing
kubectl get pods -n ticketing -w        # gledaj kako prelaze u Ready
```
Sve replike trebaju biti `Running` i `READY n/n`. Za funkcionalnu provjeru
slijedi korake "Brza validacija" iz glavnog README-a.
