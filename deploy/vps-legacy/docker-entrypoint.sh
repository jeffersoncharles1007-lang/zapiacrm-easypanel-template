#!/bin/sh
# =============================================================================
# ZAPIACRM - Docker Entrypoint
# Espera o banco ficar pronto, roda SQL na primeira vez, inicia o app
# =============================================================================

set -e

echo "============================================"
echo "  ZAPIACRM - Starting..."
echo "============================================"

# Aguarda o postgres ficar pronto (max 60s)
echo "[1/4] Aguardando banco de dados..."
i=0
until pg_isready -h postgres -p 5432 -U "${POSTGRES_USER:-admin}" 2>/dev/null; do
  i=$((i+1))
  if [ $i -gt 30 ]; then
    echo "ERRO: Banco nao ficou pronto em 60s"
    exit 1
  fi
  echo "  Aguardando postgres... ($i/30)"
  sleep 2
done
echo "  -> Banco OK"

# EXPORT senha para psql pegar
export PGPASSWORD="${POSTGRES_PASSWORD}"

# Verifica se o banco precisa de setup
echo "[2/4] Verificando se banco precisa de setup..."
TABLE_EXISTS=$(psql -h postgres -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-zapiacrm}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='app_config');" 2>/dev/null || echo "false")

if [ "$TABLE_EXISTS" != "t" ]; then
  echo "  -> Banco vazio. Rodando 00_setup_database.sql..."
  psql -h postgres -U "${POSTGRES_USER:-admin}" -d "${POSTGRES_DB:-zapiacrm}" -f /app/sql/00_setup_database.sql 2>&1 | tail -5
  echo "  -> Banco configurado!"
else
  echo "  -> Banco ja configurado (pulando setup)"
fi

# Gera arquivo .env
echo "[3/4] Configurando variaveis de ambiente..."
cat > /app/.env << EOF
DATABASE_URL=${DATABASE_URL}
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_PROJECT_ID=${SUPABASE_PROJECT_ID}
SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}
SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
VITE_SUPABASE_URL=${VITE_SUPABASE_URL:-${SUPABASE_URL}}
VITE_SUPABASE_PROJECT_ID=${VITE_SUPABASE_PROJECT_ID:-${SUPABASE_PROJECT_ID}}
VITE_SUPABASE_PUBLISHABLE_KEY=${VITE_SUPABASE_PUBLISHABLE_KEY:-${SUPABASE_PUBLISHABLE_KEY}}
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
VITE_GOOGLE_CLIENT_ID=${VITE_GOOGLE_CLIENT_ID:-${GOOGLE_CLIENT_ID}}
GOOGLE_API_KEY=${GOOGLE_API_KEY}
VITE_GOOGLE_API_KEY=${GOOGLE_API_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
EVOLUTION_API_URL=${EVOLUTION_API_URL}
EVOLUTION_API_KEY=${EVOLUTION_API_KEY}
VITE_EVOLUTION_API_URL=${VITE_EVOLUTION_API_URL:-${EVOLUTION_API_URL}}
NODE_ENV=${NODE_ENV:-production}
HOST=${HOST:-0.0.0.0}
PORT=${PORT:-4000}
EOF
echo "  -> .env gerado"

# Inicia o app
echo "[4/4] Iniciando ZAPIACRM na porta ${PORT:-4000}..."
echo "============================================"
exec node .output/server/index.mjs