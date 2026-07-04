# =============================================================================
# ZAPIACRM - Dockerfile para Easypanel
# Constroi a imagem do app ZAPIACRM (TanStack Start + Vite + React)
# =============================================================================

# Stage 1: Build do frontend/backend
FROM node:20-alpine AS builder

WORKDIR /app

# Instala git (necessario para algumas deps do TanStack)
RUN apk add --no-cache git

# Copia apenas os arquivos de deps primeiro (cache do Docker)
COPY package*.json ./
COPY bun.lock* ./

# Instala dependencias
RUN npm install --no-audit --no-fund

# Copia o resto do codigo
COPY . .

# Build de producao (gera .output/server)
RUN npm run build

# Stage 2: Imagem final (so o necessario para rodar)
FROM node:20-alpine AS runner

WORKDIR /app

# Instala postgres-client (para o entrypoint verificar o banco)
RUN apk add --no-cache postgresql-client wget

# Variaveis de ambiente padrao
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=4000

# Copia o build do stage anterior
COPY --from=builder /app/.output ./.output
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Copia scripts SQL para o entrypoint usar
COPY --from=builder /app/sql/00_setup_database.sql ./sql/00_setup_database.sql
COPY --from=builder /app/sql/00_cleanup.sql ./sql/00_cleanup.sql

# Copia o entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/ || exit 1

EXPOSE 4000

ENTRYPOINT ["docker-entrypoint.sh"]