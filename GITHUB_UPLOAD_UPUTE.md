# 📤 Kako uploadati projekt na GitHub – korak po korak

**Autor: Lovro Siprak**

Cilj: cijeli sadržaj mape `secure-event-ticketing` staviti na GitHub kao
repozitorij (kao što je kolega napravio), tako da `README.md` bude u korijenu
repozitorija. Slijedi **Opciju A** (najlakša i najpouzdanija). Opcije B i C su
alternative.

> Važno: ime repozitorija neka bude **`secure-event-ticketing`** jer je taj URL
> već naveden u podnožju Word dokumenta (`github.com/<tvoj-username>/secure-event-ticketing`).
> Ako odabereš drugo ime, samo promijeni URL u dokumentu.

---

## Korak 0 – Napravi GitHub račun (ako ga nemaš)

1. Idi na <https://github.com/signup>.
2. Upiši email, lozinku i korisničko ime (zapamti username – ići će u URL).
3. Potvrdi email. Gotovo.

---

## OPCIJA A – GitHub Desktop (preporuka, grafičko sučelje)

### A1. Instaliraj GitHub Desktop
1. Idi na <https://desktop.github.com/> → **Download for Windows** → instaliraj.
2. Pokreni ga i **File → Options → Accounts → Sign in** sa svojim GitHub računom.

### A2. Dodaj projekt kao repozitorij
1. U GitHub Desktopu: **File → Add local repository…**
2. Klikni **Choose…** i odaberi mapu:
   `C:\Users\Lovro\Claude\Projects\DevOps\secure-event-ticketing`
3. Pojavit će se poruka *"This directory does not appear to be a Git repository"*
   s ponudom **„create a repository"** – klikni na tu plavu poveznicu.
4. Otvori se prozor **Create a repository**:
   - **Name:** `secure-event-ticketing`
   - **Description:** npr. `DevSecOps projekt – Secure Event Ticketing Platform`
   - Ostalo ostavi kako jest (Git ignore i licencu ne diraj – već imaš `.gitignore`).
   - Klikni **Create repository**.

### A3. Prvi commit
1. U lijevom stupcu vidjet ćeš popis svih datoteka (sve su „označene").
2. Dolje lijevo u polje **Summary** upiši: `Inicijalni commit – Lovro Siprak`
3. Klikni plavi gumb **Commit to main**.

### A4. Objavi na GitHub
1. Gore klikni **Publish repository**.
2. U prozoru:
   - Ostavi ime `secure-event-ticketing`.
   - **Odznači** „Keep this code private" ako želiš da repo bude **javan**
     (preporuka za predaju, kao kod kolege). Ako želiš privatno, ostavi kvačicu.
   - Klikni **Publish repository**.
3. Nakon par sekundi: **Repository → View on GitHub** → otvori se tvoj repo u pregledniku. 🎉

### A5. (Kasnije) Ako nešto promijeniš
Svaki put kad promijeniš datoteke: upiši novi **Summary** → **Commit to main**
→ gore **Push origin**. Time se promjene pošalju na GitHub.

---

## OPCIJA B – Preko web stranice (drag & drop)

> ⚠️ Mana: preglednik pri povlačenju mapa **često preskoči skrivene mape/datoteke**
> (`.github`, `.gitignore`, `.dockerignore`). Bez `.github/workflows/ci.yml` nema
> CI/CD-a, što je dio ocjene. Zato koristi ovu opciju samo ako baš ne želiš
> instalirati GitHub Desktop, i provjeri Korak B4.

1. Na GitHubu gore desno **+ → New repository**.
2. **Repository name:** `secure-event-ticketing`, odaberi **Public**, **Create repository**.
3. Na sljedećoj stranici klikni **„uploading an existing file"**.
4. Otvori mapu `secure-event-ticketing` u File Exploreru, označi **sav sadržaj**
   (Ctrl+A) i povuci u preglednik. Dolje upiši commit poruku i **Commit changes**.
5. **Provjeri** je li se uploadala mapa `.github/workflows/` s datotekom `ci.yml`.
   Ako nije, ručno je dodaj: na repo stranici **Add file → Create new file**, u
   polje imena upiši `.github/workflows/ci.yml` (kose crte automatski stvaraju
   mape), zalijepi sadržaj iz lokalne datoteke i **Commit**.

---

## OPCIJA C – Git iz komandne linije (za naprednije)

Otvori PowerShell u mapi projekta i pokreni redom (zamijeni `<USERNAME>`):

```powershell
cd C:\Users\Lovro\Claude\Projects\DevOps\secure-event-ticketing
git init
git add .
git commit -m "Inicijalni commit - Lovro Siprak"
git branch -M main
git remote add origin https://github.com/<USERNAME>/secure-event-ticketing.git
git push -u origin main
```

Ako te pita za prijavu, slijedi upute (najlakše kroz GitHub Desktop ili
osobni token). Git prvo instaliraj s <https://git-scm.com/download/win> ako ga nemaš.

---

## Što se NEĆE (i ne smije) uploadati

Datoteka `.gitignore` već brine da se **ne** pošalju tajne i smeće:
`.env`, `node_modules/`, logovi, scan artefakti. To je namjerno i ispravno –
u repo ide samo `.env.example` (predložak bez pravih lozinki).

---

## Treba li i Word dokument u repo?

Kolega ima samo kod na GitHubu, a Word izvještaj se obično predaje zasebno
(npr. u sustav fakulteta / e-mailom profesoru). Ako ipak želiš i dokument u
repozitoriju, samo prebaci `Lovro_Siprak_DevOps_Projekt.docx` u mapu projekta i
napravi commit (Opcija A, korak A5) – ili ga povuci u web sučelje (Opcija B).

---

## Finalna provjera (checklist)

- [ ] Repo se otvara na `github.com/<USERNAME>/secure-event-ticketing`
- [ ] U korijenu se vidi `README.md` (prikazuje se ispod popisa datoteka)
- [ ] Postoje mape `api/`, `frontend/`, `worker/`, `k8s/`, `helm/`, `docs/`
- [ ] Postoji `.github/workflows/ci.yml` (klikni na **Actions** tab – pipeline bi se trebao pokrenuti)
- [ ] **Nema** datoteke `.env` u repozitoriju (smije postojati samo `.env.example`)

Sretno! — *Lovro Siprak*
