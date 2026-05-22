# ══════════════════════════════════════════════════════════════════════
# Fiers Artisans — Admin Web Dockerfile (Next.js multi-stage)
# ══════════════════════════════════════════════════════════════════════

# ── Stage 1 : Development ────────────────────────────────────────────
FROM node:24-alpine AS development

WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY package*.json ./
RUN npm ci
COPY . .

# ── Stage 2 : Build ──────────────────────────────────────────────────
FROM development AS build
RUN npm run build

# ── Stage 3 : Production ─────────────────────────────────────────────
FROM node:24-alpine AS production

WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=build /app/package*.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/next.config.ts ./next.config.ts

EXPOSE 3002
CMD ["npm", "run", "start"]
