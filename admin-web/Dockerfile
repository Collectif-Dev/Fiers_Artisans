# ══════════════════════════════════════════════════════════════════════
# Fiers Artisans — Admin Web Dockerfile (Next.js multi-stage)
# ══════════════════════════════════════════════════════════════════════

# ── Stage 1 : Development ────────────────────────────────────────────
FROM node:22.22.3-bookworm-slim@sha256:e21fc383b50d5347dc7a9f1cae45b8f4e2f0d39f7ade28e4eef7d2934522b752 AS development

WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

COPY package*.json ./
RUN npm ci

COPY . .

CMD ["npm", "run", "dev"]

# ── Stage 2 : Build ──────────────────────────────────────────────────
FROM development AS build

RUN npm run build

# ── Stage 3 : Production ─────────────────────────────────────────────
FROM node:22.22.3-bookworm-slim@sha256:e21fc383b50d5347dc7a9f1cae45b8f4e2f0d39f7ade28e4eef7d2934522b752 AS production

WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3002
ENV HOSTNAME=0.0.0.0

COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public
COPY --from=build /app/next.config.ts ./next.config.ts

USER node

EXPOSE 3002

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3002', (r) => process.exit(r.statusCode < 500 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]
