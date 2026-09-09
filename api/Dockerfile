# =============================================================================
# API servis - multi-stage build
# Autor: Lovro Siprak
# Cilj: minimalna runtime slika + non-root korisnik (sigurnosni zahtjev I2)
# =============================================================================

# ---- Stage 1: deps (instaliraj SAMO produkcijske ovisnosti) ----
FROM node:20-alpine AS deps
WORKDIR /app
# Kopiramo prvo package datoteke radi boljeg Docker cache-a (sloj se ne mijenja
# dok se ovisnosti ne promijene -> brzi ponovni build -> mjerljivo brza isporuka I3)
COPY package*.json ./
# Instaliramo SAMO produkcijske ovisnosti. Ako je uz package.json prisutan i
# package-lock.json, npm ga automatski postuje (deterministicno). --no-audit/--no-fund
# ubrzavaju build i smanjuju sum u logovima.
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

# ---- Stage 2: runtime (sto manja slika) ----
FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

# Sigurnosni "housekeeping": prvo nadogradnja svih OS paketa na zadnje zakrpane
# verzije (uklanja poznate ranjivosti baze -> Trivy gate u CI-u prolazi), zatim
# tini za ispravno rukovanje signalima (SIGTERM). wget vec postoji u busyboxu i
# koristimo ga za HEALTHCHECK.
RUN apk --no-cache upgrade && apk add --no-cache tini

# npm ne treba za pokretanje (koristimo "node src/server.js"); micanjem npm-a iz
# runtime slike smanjujemo napadnu povrsinu i uklanjamo ranjivosti npm ovisnosti.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Kopiramo gotove node_modules iz deps stagea i izvorni kod aplikacije
COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY src ./src

# Slika se vrti kao ugradeni non-root korisnik "node" (UID 1000), NIKAD kao root
USER node

EXPOSE 8080

# Healthcheck na ugradeni /healthz endpoint (vidi src/server.js)
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

# tini kao PID 1 -> uredno gasenje (graceful shutdown)
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/server.js"]

# ---- Stage: dev (SAMO za lokalni razvoj / Compose, hot-reload preko nodemona) ----
# Koristi se s "target: dev" u compose.yaml. Izvorni kod se mounta kao volume,
# pa nodemon automatski restarta proces na svaku promjenu (zahtjev 1. dijela).
FROM node:20-alpine AS dev
ENV NODE_ENV=development
WORKDIR /app
RUN apk --no-cache upgrade && apk add --no-cache tini
COPY package*.json ./
RUN npm install
COPY src ./src
EXPOSE 8080
USER node
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["npm", "run", "dev"]
