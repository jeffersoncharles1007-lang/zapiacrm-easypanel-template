#!/bin/bash
# =============================================================================
# ZAPIACRM - INSTALADOR 1-CLICK
# Cliente so precisa rodar este comando:
#   curl -fsSL https://raw.githubusercontent.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/main/install-1click.sh | bash
#
# Pergunta APENAS 1 coisa: o IP/dominio da VPS
# Credenciais do Evolution API e Google ja vem embutidas (centralizadas pelo dev)
# =============================================================================

set -e

# ===== CREDENCIAIS CENTRALIZADAS =====
# Sao preenchidas via curl de um endpoint seguro, NAO commitadas aqui
# Para atualizar, edite no servidor de credenciais e rode novamente

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
echo -e "${GREEN}Instalacao em 5 minutos.${NC}"
echo -e "${GREEN}Voce so precisa digitar o IP da VPS quando perguntar.${NC}"
echo ""

# ===== 1. Verificar/Instalar Docker =====
echo -e "${BLUE}[1/4] Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
  echo "  Instalando Docker..."
  curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
  echo -e "${GREEN}  ✓ Docker instalado${NC}"
else
  echo -e "${GREEN}  ✓ Docker OK${NC}"
fi

# ===== 2. Perguntar SÓ o IP/dominio =====
echo ""
echo -e "${BLUE}[2/4] Configuracao${NC}"
echo ""
echo -e "${CYAN}Qual o IP da VPS ou dominio?${NC}"
echo -e "${YELLOW}(Ex: 123.456.78.90 ou crm.suaempresa.com.br)${NC}"
echo -n -e "${YELLOW}→ ${NC}"
read -r DOMAIN

# ===== 3. Criar arquivos de configuracao =====
echo ""
echo -e "${BLUE}[3/4] Preparando instalacao...${NC}"

# Gerar senhas aleatorias para o banco
DB_PASSWORD=$(openssl rand -hex 16)
ANON_KEY="local-anon-$(openssl rand -hex 16)"
SERVICE_KEY="local-service-$(openssl rand -hex 16)"

INSTALL_DIR="/opt/zapiacrm"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Baixar docker-compose.yml do GitHub
curl -fsSL https://raw.githubusercontent.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/main/docker-compose.yml -o docker-compose.yml > /dev/null 2>&1

# Criar .env local com credenciais embutidas + senhas geradas
cat > .env << EOF
PROJECT_NAME=zapiacrm
POSTGRES_DB=zapiacrm
POSTGRES_USER=admin
POSTGRES_PASSWORD=$DB_PASSWORD
APP_PORT=4000

# Supabase local (gerado automaticamente)
SUPABASE_URL=http://$DOMAIN:4000
SUPABASE_PROJECT_ID=internal
SUPABASE_PUBLISHABLE_KEY=$ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SERVICE_KEY

# Google OAuth (credenciais centralizadas)
GOOGLE_CLIENT_ID=$GOOGLE_CID
GOOGLE_CLIENT_SECRET=$GOOGLE_SEC

# Evolution API central (WhatsApp - credenciais centralizadas)
EVOLUTION_API_URL=$EVOLUTION_URL
EVOLUTION_API_KEY=$EVOLUTION_KEY

# Chaves de IA (cliente configura depois pelo painel)
GOOGLE_API_KEY=
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
EOF

echo -e "${GREEN}  ✓ Arquivos prontos${NC}"

# ===== 4. Subir containers =====
echo ""
echo -e "${BLUE}[4/4] Iniciando ZAPIACRM (~3-5 min, nao feche esta janela)...${NC}"
docker compose up -d

echo ""
echo -e "${YELLOW}Aguardando sistema inicializar...${NC}"
for i in {1..40}; do
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
echo -e "${BLUE}Proximos passos:${NC}"
echo "  1. Abra o link acima"
echo "  2. Clique em 'Criar conta' (voce sera o admin)"
echo "  3. Va em /master/painel"
echo "  4. Clique em 'Conectar WhatsApp' e escaneie o QR Code"
echo ""
echo -e "${BLUE}Comandos uteis:${NC}"
echo "  ${YELLOW}cd /opt/zapiacrm && docker compose logs -f${NC}   # ver logs"
echo "  ${YELLOW}cd /opt/zapiacrm && docker compose restart${NC}  # reiniciar"
echo ""
echo -e "${GREEN}Sistema funcionando 24/7!${NC}"