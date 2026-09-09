# =============================================================================
# Frontend servis - multi-stage build
# Autor: Lovro Siprak
# =============================================================================

FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
# Samo produkcijske ovisnosti; ako postoji package-lock.json, npm ga postuje.
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
# Nadogradnja OS paketa + tini; micanje npm-a iz runtime slike (nije potreban za
# pokretanje) radi manje napadne povrsine i uklanjanja ranjivosti npm ovisnosti.
RUN apk --no-cache upgrade && apk add --no-cache tini \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY src ./src
USER node
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/healthz || exit 1
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
EXPOSE 3000
USER node
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["npm", "run", "dev"]
