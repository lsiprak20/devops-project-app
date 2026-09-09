# I1 – Kritička procjena: kontejneri vs. virtualne mašine

**Autor: Lovro Siprak**

Ovaj dokument obrazlaže odluku da se *Secure Event Ticketing Platform*
isporučuje kao skup **kontejnera** umjesto kao aplikacija na **virtualnim
mašinama (VM)**, te navodi i situacije u kojima bi VM bio bolji izbor.

## 1. Što se uspoređuje

| Svojstvo | Kontejner | Virtualna mašina |
|---|---|---|
| Razina izolacije | Proces + namespace/cgroups, dijeli kernel hosta | Cijeli gostujući OS s vlastitim kernelom |
| Veličina artefakta | Deseci–stotine MB (kod nas `alpine`, ~50–150 MB) | Gigabajti (cijeli OS) |
| Vrijeme pokretanja | Sekunde ili manje | Desetci sekundi do minute |
| Gustoća (broj na hostu) | Visoka (dijele kernel i resurse) | Niža (svaki nosi OS) |
| Reproducibilnost | Vrlo visoka (slika je nepromjenjiv artefakt) | Slabija (često "snowflake" serveri) |
| Izolacija (sigurnost) | Slabija od VM (dijeli kernel) | Jača (hardverska/hypervisor granica) |

## 2. Zašto kontejneri za ovaj projekt

1. **Pet malih, neovisnih servisa.** Frontend, api i worker su lagani Node.js
   procesi. Pokrenuti pet zasebnih VM-ova za njih bilo bi rasipanje resursa;
   kontejneri dijele kernel i troše red veličine manje memorije.
2. **Brza i reproducibilna isporuka (cilj I3).** Slika izgrađena iz
   `Dockerfile`-a je nepromjenjiv artefakt s fiksnim tagom (git SHA). Ista slika
   koja prođe testove i skeniranje ide u produkciju – nema "radi na mom računalu".
3. **Identično okruženje lokalno i u produkciji.** Isti `Dockerfile` koristi se
   za Compose (lokalno) i za Kubernetes (produkcija), uz minimalne razlike.
4. **Orkestracija (cilj I6).** Kubernetes je dizajniran oko kontejnera: probe,
   rolling update, skaliranje i self-healing dolaze "iz kutije".
5. **Brzo skaliranje.** Novi `api` pod se digne u sekundama pri navali prometa;
   nova VM bi se bootala znatno duže.

## 3. Kada bi VM bio bolji izbor

Kontejneri nisu uvijek pravi alat. VM (ili čak fizički server) je primjereniji:

- **Jača izolacija za netrusteni kod ili stroge compliance zahtjeve** – jer VM
  ima hardverski podržanu granicu, dok kontejneri dijele kernel hosta.
- **Aplikacije koje traže vlastiti kernel ili kernel module**, drugi OS
  (npr. Windows servis na Linux hostu) ili specifične drivere.
- **Monolitne legacy aplikacije** koje se ne mogu lako razložiti na servise.
- **Stateful sustavi s vrlo visokim I/O** gdje se želi puna kontrola nad OS-om
  i diskovima.

## 4. Hibridni pristup (realnost)

U praksi se često kombinira: Kubernetes čvorovi **jesu** VM-ovi (u oblaku), a na
njima se vrte kontejneri. Tako se dobiva izolacija na razini čvora (VM) i
gustoća/agilnost na razini aplikacije (kontejner). I ovaj projekt je takav –
kontejneri na Kubernetes čvorovima.

## 5. Zaključak

Za sustav od pet malih servisa s potrebom za brzom, reproducibilnom isporukom i
orkestracijom, **kontejneri su jasno ispravan izbor**. Glavni kompromis –
slabija izolacija od VM-a – ublažava se sigurnosnim kontrolama: non-root
korisnik, `drop ALL` capabilities, `readOnlyRootFilesystem`, seccomp profil,
NetworkPolicy segmentacija i skeniranje slika prije deploya (vidi
`docs/security/image-scan-report.md`).
