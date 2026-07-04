#!/bin/bash
# =============================================================================
# ZAPIACRM - INSTALADOR MINIMALISTA COM FALLBACK
#
# Tenta baixar imagem do Docker Hub.
# Se falhar, faz build local automaticamente.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/main/install-minimal.sh | bash
#
# =============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# URLs
BASE_URL="https://raw.githubusercontent.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/main"
REPO_URL="https://github.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template.git"
CREDENTIALS_URL="https://github.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/releases/download/v1.0-credentials/credentials.env"
DOCKERHUB_IMAGE="jeffersonnegocios1007/zapiacrm-app:latest"

INSTALL_DIR="/opt/zapiacrm"
USE_DOCKERHUB=true

clear
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║              ZAPIACRM - INSTALAÇÃO RÁPIDA                   ║"
echo "║                                                              ║"
echo "║              CRM + WhatsApp + IA em 3 minutos                ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ===== 1. Verificar Docker =====
echo -e "${BLUE}[1/5] Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
  echo -e "${YELLOW}  Docker não encontrado. Instalando...${NC}"
  curl -fsSL https://get.docker.com | sh
  service docker start 2>/dev/null || true
  echo -e "${GREEN}  ✓ Docker instalado${NC}"
else
  echo -e "${GREEN}  ✓ Docker OK${NC}"
fi

# Verificar docker compose
if ! docker compose version &> /dev/null && ! docker-compose --version &> /dev/null; then
  echo -e "${RED}  ✗ docker compose não encontrado${NC}"
  exit 1
fi
echo -e "${GREEN}  ✓ docker compose OK${NC}"

# ===== 2. Preparar diretório =====
echo ""
echo -e "${BLUE}[2/5] Preparando diretório...${NC}"
if [ -d "$INSTALL_DIR" ]; then
  echo -e "${YELLOW}  Removendo instalação anterior...${NC}"
  docker compose -f "$INSTALL_DIR/docker-compose.yml" down -v 2>/dev/null || true
  rm -rf "$INSTALL_DIR"
fi
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
echo -e "${GREEN}  ✓ Diretório pronto: $INSTALL_DIR${NC}"

# ===== 3. Baixar credenciais centralizadas =====
echo ""
echo -e "${BLUE}[3/5] Baixando credenciais...${NC}"
TMP_CREDS=$(mktemp)
if curl -fsSL "$CREDENTIALS_URL" -o "$TMP_CREDS" 2>/dev/null; then
  source "$TMP_CREDS"
  echo -e "${GREEN}  ✓ Credenciais obtidas${NC}"
else
  echo -e "${YELLOW}  ⚠ Não foi possível baixar credenciais${NC}"
  # Usar placeholders
  EVOLUTION_API_URL="https://evolution-api-placeholder.example.com"
  EVOLUTION_API_KEY="placeholder"
  GOOGLE_CLIENT_ID="placeholder.apps.googleusercontent.com"
  GOOGLE_CLIENT_SECRET="placeholder"
fi
rm -f "$TMP_CREDS"

# Gerar senhas
DB_PASS="zap$(openssl rand -hex 4 2>/dev/null || echo "1acrm2026")"

# ===== 4. Tentar Docker Hub primeiro, senão git clone =====
echo ""
echo -e "${BLUE}[4/5] Baixando imagem do sistema...${NC}"

# Tentar Docker Hub
echo -e "${CYAN}  Tentando baixar do Docker Hub...${NC}"
if docker pull "$DOCKERHUB_IMAGE" 2>&1 | tail -5; then
  echo -e "${GREEN}  ✓ Imagem do Docker Hub OK${NC}"
  USE_DOCKERHUB=true
else
  echo -e "${YELLOW}  ⚠ Docker Hub não disponível. Fazendo build local...${NC}"
  USE_DOCKERHUB=false
fi

if [ "$USE_DOCKERHUB" = false ]; then
  # Git clone para build local
  echo -e "${CYAN}  Clonando repositório para build local...${NC}"
  rm -rf /tmp/zapiacrm-build
  if git clone --depth 1 "$REPO_URL" /tmp/zapiacrm-build 2>&1 | tail -3; then
    echo -e "${GREEN}  ✓ Repositório clonado${NC}"

    # Copiar arquivos necessários
    cp /tmp/zapiacrm-build/docker-compose.yml ./
    cp /tmp/zapiacrm-build/docker-entrypoint.sh ./
    chmod +x docker-entrypoint.sh

    # Copiar SQL files
    if [ -d "/tmp/zapiacrm-build/sql" ]; then
      mkdir -p "$INSTALL_DIR/sql"
      cp /tmp/zapiacrm-build/sql/*.sql "$INSTALL_DIR/sql/" 2>/dev/null || true
    fi

    # Build local
    echo -e "${CYAN}  Fazendo build local (isso demora ~5 minutos)...${NC}"
    cd /tmp/zapiacrm-build
    if docker build --no-cache -t zapiacrm-local:latest . 2>&1 | tail -10; then
      echo -e "${GREEN}  ✓ Build local concluído${NC}"
    else
      echo -e "${RED}  ✗ Build local falhou${NC}"
      exit 1
    fi

    cd "$INSTALL_DIR"
    sed -i "s|image:.*jefferson.*|image: zapiacrm-local:latest|" docker-compose.yml
  else
    echo -e "${RED}  ✗ Não foi possível baixar o projeto${NC}"
    exit 1
  fi
fi

# ===== 5. Configuração =====
echo ""
echo -e "${BLUE}[5/5] Configuração...${NC}"

# Gerar keys
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJ6YXBpYWNybSIsInJvbGUiOiJhbm9uIn0.$(openssl rand -hex 16 2>/dev/null || echo "placeholder")"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJ6YXBpYWNybSIsInJvbGUiOiJzZXJ2aWNlIn0.$(openssl rand -hex 16 2>/dev/null || echo "placeholder")"

cat > .env << EOF
PROJECT_NAME=zapiacrm
POSTGRES_DB=zapiacrm
POSTGRES_USER=admin
POSTGRES_PASSWORD=$DB_PASS
APP_PORT=4000
SUPABASE_URL=http://localhost:4000
SUPABASE_PROJECT_ID=zapiacrm-local
SUPABASE_PUBLISHABLE_KEY=$ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SERVICE_KEY
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
EVOLUTION_API_URL=${EVOLUTION_API_URL}
EVOLUTION_API_KEY=${EVOLUTION_API_KEY}
GOOGLE_API_KEY=
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
EOF

echo -e "${GREEN}  ✓ Configuração gerada${NC}"

# ===== 6. Iniciar serviços =====
echo ""
echo -e "${BLUE}[6/6] Iniciando ZAPIACRM...${NC}"
docker compose up -d

echo ""
echo -e "${YELLOW}  Aguardando sistema inicializar...${NC}"
for i in {1..24}; do
  if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ Sistema iniciado!${NC}"
    break
  fi
  echo "    Tentativa $i/24..."
  sleep 5
done

# ===== Resultado =====
clear
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║                  ✅ SISTEMA PRONTO!                          ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}  🌐 Acesse no navegador:${NC}"
echo ""
echo -e "     ${CYAN}http://localhost:4000${NC}"
echo ""
echo -e "${BLUE}  📋 Comandos úteis:${NC}"
echo -e "     ${YELLOW}cd $INSTALL_DIR && docker compose logs -f${NC}  (ver logs)"
echo -e "     ${YELLOW}cd $INSTALL_DIR && docker compose restart${NC}  (reiniciar)"
echo -e "     ${YELLOW}cd $INSTALL_DIR && docker compose down${NC}     (parar)"
echo ""
echo -e "${GREEN}  ⏱️  Sistema rodando 24/7!${NC}"
echo ""
