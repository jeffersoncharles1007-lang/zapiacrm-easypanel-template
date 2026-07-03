#!/bin/bash
# =============================================================================
# ZAPIACRM - INSTALADOR 1-CLICK
# Cliente so precisa rodar este comando:
#   curl -fsSL https://raw.githubusercontent.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/main/install-1click.sh | bash
#
# Pergunta APENAS 1 coisa: o IP/dominio da VPS
# Faz git clone do repositorio inteiro para buildar localmente
# =============================================================================

set -e

# URL do release com credenciais
CREDENTIALS_URL="https://github.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/releases/download/v1.0-credentials/credentials.env"

# URL do repositorio template
REPO_URL="https://github.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template.git"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "============================================================"
echo "          ZAPIACRM - Instalador Automatico"
echo "============================================================"
echo -e "${NC}"
echo ""
echo -e "${GREEN}Instalacao em 10 minutos.${NC}"
echo -e "${GREEN}Voce so precisa digitar o IP da VPS quando perguntar.${NC}"
echo ""

# ===== 1. Verificar/Instalar Docker =====
echo -e "${BLUE}[1/5] Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
  echo "  Instalando Docker..."
  curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
  echo -e "${GREEN}  ✓ Docker instalado${NC}"
else
  echo -e "${GREEN}  ✓ Docker OK${NC}"
fi

# Verificar git (necessario para clonar)
if ! command -v git &> /dev/null; then
  echo "  Instalando git..."
  apt-get install -y -qq git > /dev/null 2>&1 || yum install -y -q git > /dev/null 2>&1
  echo -e "${GREEN}  ✓ git instalado${NC}"
fi

# ===== 2. Baixar credenciais centralizadas =====
echo ""
echo -e "${BLUE}[2/5] Baixando credenciais centralizadas...${NC}"
TMP_CREDS=$(mktemp)
curl -fsSL "$CREDENTIALS_URL" -o "$TMP_CREDS" 2>/dev/null || {
  echo -e "${RED}  ✗ Erro ao baixar credenciais${NC}"
  exit 1
}
echo -e "${GREEN}  ✓ Credenciais obtidas${NC}"

# Carregar credenciais em variaveis
EVOLUTION_URL=$(grep '^EVOLUTION_API_URL=' "$TMP_CREDS" | cut -d= -f2-)
EVOLUTION_KEY=$(grep '^EVOLUTION_API_KEY=' "$TMP_CREDS" | cut -d= -f2-)
GOOGLE_CID=$(grep '^GOOGLE_CLIENT_ID=' "$TMP_CREDS" | cut -d= -f2-)
GOOGLE_SEC=$(grep '^GOOGLE_CLIENT_SECRET=' "$TMP_CREDS" | cut -d= -f2-)
rm -f "$TMP_CREDS"

# ===== 3. Clonar repositorio =====
echo ""
echo -e "${BLUE}[3/5] Clonando repositorio do projeto...${NC}"
INSTALL_DIR="/opt/zapiacrm"
rm -rf "$INSTALL_DIR"
git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>&1 | tail -3
cd "$INSTALL_DIR"
echo -e "${GREEN}  ✓ Codigo do projeto baixado${NC}"

# ===== 4. Perguntar SÓ o IP/dominio e criar .env =====
echo ""
echo -e "${BLUE}[4/5] Configuracao${NC}"
echo ""
echo -e "${CYAN}Qual o IP da VPS ou dominio?${NC}"
echo -e "${YELLOW}(Ex: 123.456.78.90 ou crm.suaempresa.com.br)${NC}"
echo -n -e "${YELLOW}→ ${NC}"
read -r DOMAIN

# Gerar senhas aleatorias para o banco
DB_PASSWORD="zapiacrm2026"
ANON_KEY="local-anon-$(openssl rand -hex 16)"
SERVICE_KEY="local-service-$(openssl rand -hex 16)"

# Criar .env
cat > .env << EOF
PROJECT_NAME=zapiacrm
POSTGRES_DB=zapiacrm
POSTGRES_USER=admin
POSTGRES_PASSWORD=$DB_PASSWORD
APP_PORT=4000

SUPABASE_URL=http://$DOMAIN:4000
SUPABASE_PROJECT_ID=internal
SUPABASE_PUBLISHABLE_KEY=$ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SERVICE_KEY

GOOGLE_CLIENT_ID=$GOOGLE_CID
GOOGLE_CLIENT_SECRET=$GOOGLE_SEC

EVOLUTION_API_URL=$EVOLUTION_URL
EVOLUTION_API_KEY=$EVOLUTION_KEY

GOOGLE_API_KEY=
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
EOF

echo -e "${GREEN}  ✓ Configuracao salva${NC}"

# ===== 5. Subir containers =====
echo ""
echo -e "${BLUE}[5/5] Iniciando ZAPIACRM (~5-10 min, nao feche esta janela)...${NC}"
echo "  - Postgres"
echo "  - Evolution API (WhatsApp)"
echo "  - ZAPIACRM (app principal)"
echo ""
docker compose up -d --build

echo ""
echo -e "${YELLOW}Aguardando sistema inicializar (~3 min para build)...${NC}"
for i in {1..60}; do
  if curl -s http://localhost:4000 > /dev/null 2>&1; then
    break
  fi
  sleep 5
done

# ===== Resultado final =====
clear
echo ""
echo -e "${GREEN}============================================================"
echo "       SISTEMA PRONTO!"
echo "============================================================${NC}"
echo ""
echo -e "${YELLOW}>>> Acesse no navegador: <<<${NC}"
echo ""
echo -e "    ${CYAN}http://$DOMAIN:4000${NC}"
echo ""
echo -e "${BLUE}Outros servicos:${NC}"
echo "  Evolution API (WhatsApp): ${CYAN}http://$DOMAIN:8080/manager${NC}"
echo ""
echo -e "${BLUE}Proximos passos:${NC}"
echo "  1. Abra o link acima"
echo "  2. Clique em 'Criar conta' (voce sera o admin)"
echo "  3. Va em /master/painel"
echo "  4. Em WhatsApp, escaneie o QR Code em http://$DOMAIN:8080/manager"
echo ""
echo -e "${BLUE}Comandos uteis:${NC}"
echo "  ${YELLOW}cd /opt/zapiacrm && docker compose logs -f${NC}   # ver logs"
echo "  ${YELLOW}cd /opt/zapiacrm && docker compose restart${NC}  # reiniciar"
echo "  ${YELLOW}cd /opt/zapiacrm && docker compose ps${NC}       # ver status"
echo ""
echo -e "${BLUE}Credenciais do banco (caso precise):${NC}"
echo "  Host: postgres (interno) ou localhost (externo)"
echo "  Database: zapiacrm"
echo "  User: admin"
echo "  Password: ${CYAN}zapiacrm2026${NC}"
echo ""
echo -e "${GREEN}Sistema funcionando 24/7!${NC}"