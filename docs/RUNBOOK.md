# Runbook – incidenti i troubleshooting

**Autor: Lovro Siprak**

Pokriva ishod učenja **I5** (realni incidentni scenariji, dijagnostika i analiza
uzroka, korektivne mjere i validacija, sistematičan postupak).

---

## 0. Opći, sistematičan postupak (uvijek ovim redom)

1. **Stabiliziraj sliku stanja** – ne mijenjaj ništa dok ne vidiš što se događa.
   ```bash
   kubectl get pods -n ticketing -o wide
   kubectl get events -n ticketing --sort-by=.lastTimestamp | tail -20
   ```
2. **Lokaliziraj** – koji servis je problematičan? (CrashLoopBackOff, 0/1 Ready…)
3. **Pogledaj logove i opis poda**:
   ```bash
   kubectl logs deploy/<servis> -n ticketing --tail=100
   kubectl describe pod <pod> -n ticketing
   ```
4. **Hipoteza → provjera → korektivna mjera** (jedna promjena u jednom trenutku).
5. **Validacija** – potvrdi da je riješeno (probe, health endpoint, test narudžbe).
6. **Zabilježi** – što se dogodilo, uzrok, mjera (kratka bilješka radi budućnosti).

Korisni health endpointi za validaciju:
```bash
kubectl port-forward svc/api 8080:8080 -n ticketing
curl http://localhost:8080/healthz   # proces živ
curl http://localhost:8080/readyz    # baza + redis dostupni
```

---

## Scenarij 1 – Pad baze (PostgreSQL nedostupan)

**Simptomi:** `/readyz` vraća `503`, API logira `Redis/PG error`, narudžbe se
gomilaju u Redisu i ne pojavljuju se u `/tickets/orders`.

**Dijagnostika:**
```bash
kubectl get pods -n ticketing -l app=postgres
kubectl describe pod -l app=postgres -n ticketing      # zašto nije Ready?
kubectl logs deploy/postgres -n ticketing --tail=100
```

**Mogući uzroci i mjere:**

| Uzrok | Provjera | Korektivna mjera |
|---|---|---|
| PVC pun / nema mjesta | `kubectl describe pvc postgres-pvc -n ticketing` | povećaj `storage` u values/manifestu, reapply |
| Pod ubijen (OOMKilled) | `kubectl describe pod` → `Last State: OOMKilled` | povećaj memory limit za postgres |
| Pod se diže (rolling/restart) | status `ContainerCreating`/`Running` ali ne Ready | pričekaj probe; provjeri `pg_isready` |

**Zašto nema gubitka podataka:** narudžbe čekaju u Redis queueu. Čim Postgres i
worker prorade, worker ih `BRPOP`-om pokupi i upiše. To je namjeran dizajn
(vidi `ARHITEKTURA.md`).

**Validacija:** `curl .../readyz` → `ready`, pa `curl .../tickets/orders` pokaže
da su zaostale narudžbe obrađene.

---

## Scenarij 2 – Loš image tag (deploy nepostojeće/krive verzije)

**Simptomi:** novi pod u `ImagePullBackOff` / `ErrImagePull`; stari podovi i
dalje rade (zbog `maxUnavailable: 0` – nema downtimea).

**Dijagnostika:**
```bash
kubectl get pods -n ticketing
kubectl describe pod <novi-pod> -n ticketing   # "Failed to pull image ...: not found"
```

**Uzrok:** krivo upisan tag, slika nije objavljena, ili nedostaju prava za
povlačenje iz privatnog registra.

**Korektivna mjera (rollback na zadnju ispravnu verziju):**
```bash
# Helm:
helm rollback ticketing -n ticketing        # vrati na prethodni release
helm history ticketing -n ticketing         # popis revizija

# Plain kubectl:
kubectl rollout undo deployment/api -n ticketing
kubectl rollout status deployment/api -n ticketing
```
Zatim ispravi tag (koristi nepromjenjivi `:<git-sha>` koji je sigurno objavljen)
i ponovno deployaj.

**Prevencija:** tagging politika po git SHA + Trivy gate (nema objave dok ne
prođe) – vidi `docs/security/image-scan-report.md`.

**Validacija:** `kubectl rollout status` → `successfully rolled out`; svi podovi
`Running`/Ready.

---

## Scenarij 3 – Neispravan secret (kriva lozinka baze)

**Simptomi:** api/worker u `CrashLoopBackOff`; logovi: `password authentication
failed for user "ticketing_user"`; `/readyz` → `503`.

**Dijagnostika:**
```bash
kubectl logs deploy/api -n ticketing --tail=50
kubectl get secret ticketing-secret -n ticketing -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
```

**Uzrok:** lozinka u `ticketing-secret` ne odgovara lozinki s kojom je baza
inicijalizirana (Postgres lozinku postavlja **samo pri prvom** kreiranju baze).

**Korektivne mjere:**

- *Ako je baza nova / smije se resetirati:* uskladi Secret pa obriši PVC da se
  baza reinicijalizira ispravnom lozinkom:
  ```bash
  kubectl apply -f k8s/03-secret.yaml
  kubectl delete pvc postgres-pvc -n ticketing   # PAŽNJA: briše podatke
  kubectl rollout restart deploy/postgres deploy/api deploy/worker -n ticketing
  ```
- *Ako podatke treba sačuvati:* promijeni lozinku **unutar** baze pa je uskladi
  u Secretu:
  ```bash
  kubectl exec -it deploy/postgres -n ticketing -- \
    psql -U ticketing_user -d ticketing -c "ALTER USER ticketing_user PASSWORD 'NovaLozinka';"
  # zatim ažuriraj Secret na istu vrijednost i restartaj api/worker
  ```

**Validacija:** podovi izađu iz CrashLoopBackOff, `/readyz` → `ready`, test
narudžba prođe do baze.

---

## Brza referenca naredbi

```bash
kubectl get pods -n ticketing                      # status svih podova
kubectl logs -f deploy/api -n ticketing            # logovi uživo
kubectl describe pod <pod> -n ticketing            # događaji i razlozi
kubectl rollout status deploy/<servis> -n ticketing
kubectl rollout undo deploy/<servis> -n ticketing  # rollback
kubectl exec -it deploy/<servis> -n ticketing -- sh
kubectl top pods -n ticketing                       # potrošnja CPU/RAM (treba metrics-server)
```
