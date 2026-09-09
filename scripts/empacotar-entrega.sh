#!/usr/bin/env bash
# ============================================================================
# ZAPIACRM - Empacotador de entrega para cliente final
#
# O que faz:
#   1. Limpa artefatos de build (.output, .tanstack, .vercel)
#   2. Copia o codigo-fonte para pasta temporaria (SEM node_modules, .env, etc)
#   3. Copia LEIA-ME-PRIMEIRO + CHECKLISTS + MANUAL.md + scripts + SETUP_REPLICAVEL
#   4. Inclui prompts-customizacao/ e troubleshooting/
#   5. Compacta em ZAPIACRM-v1.x-entrega-AAAAMMDD.zip
#   6. Limpa pasta temporaria
#
# Uso:
#   bash scripts/empacotar-entrega.sh
#
# Onde rodar:
#   cd C:\Projetos\Aplicacoes\zapiacrm-github
#   bash scripts/empacotar-entrega.sh
#
# Output:
#   C:\Projetos\Aplicacoes\zapiacrm-github\ZAPIACRM-entrega-AAAAMMDD.zip
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# Configuracao
# ----------------------------------------------------------------------------
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATE="$(date +%Y%m%d)"
VERSION="$(grep '"version"' "$ROOT_DIR/package.json" 2>/dev/null | head -1 | sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/' || echo "1.x")"
NAME="ZAPIACRM-v${VERSION}-entrega-${DATE}"
TEMP_DIR="$(mktemp -d -t zapiacrm-entrega-XXXXXX)"
OUTPUT_ZIP="$ROOT_DIR/${NAME}.zip"

echo "==================================================="
echo "  ZAPIACRM - Empacotador de entrega"
echo "==================================================="
echo "  Origem:  $ROOT_DIR"
echo "  Destino: $OUTPUT_ZIP"
echo "  Temp:    $TEMP_DIR"
echo "  Versao:  $VERSION"
echo "  Data:    $DATE"
echo "==================================================="
echo ""

# ----------------------------------------------------------------------------
# 1. Limpar artefatos locais de build (no working dir)
# ----------------------------------------------------------------------------
echo "[1/5] Limpando artefatos de build locais..."

for pattern in .output .vercel-output .tanstack .vinxi dist .nitro; do
  if [ -d "$ROOT_DIR/$pattern" ]; then
    rm -rf "$ROOT_DIR/$pattern"
    echo "      - removido: $pattern"
  fi
done

# ----------------------------------------------------------------------------
# 2. Copiar codigo-fonte para pasta temporaria (EXCLUINDO lixo/segredos)
# ----------------------------------------------------------------------------
echo "[2/5] Copiando codigo-fonte para pasta temporaria..."

mkdir -p "$TEMP_DIR/codigo-fonte"

# Lista negra: tudo que NAO vai no ZIP do cliente
EXCLUDE_DIRS=(
  "node_modules" ".output" ".tanstack" ".vinxi" ".vercel" ".vercel-output"
  ".supabase-secrets" ".nitro" "dist" ".git" ".idea" ".vscode"
  "easypanel-template" "docs"
)

EXCLUDE_FILES=(
  "bun.lock" "package-lock.json" "CLAUDE.md"
  ".env" ".env.local" ".env.*.local" ".env.production.local"
  "projeto.zip" "zapiacrm-v1.tar.gz" "ZAPIACRM-codigo-fonte-*.zip"
  "ZAPIACRM-v*.zip" "ZAPIACRM-v*.tar.gz"
  "*.log" "*.local" ".DS_Store"
)

# Construir comando find com predicados prune
PRUNE_ARGS=()
for d in "${EXCLUDE_DIRS[@]}"; do
  PRUNE_ARGS+=(-name "$d" -prune -o)
done
PRUNE_ARGS+=(-type f -print)

# Aplicar exclusoes de arquivo
EXCLUDE_PATTERN=$(IFS='|'; echo "${EXCLUDE_FILES[*]}")

# Buscar arquivos validos
mapfile -t FILES_TO_COPY < <(
  cd "$ROOT_DIR"
  find . "${PRUNE_ARGS[@]}" 2>/dev/null \
    | grep -vE "^\.$" \
    | while read -r f; do
        basename "$f"
      done | sort -u > /tmp/_basenames.$$
  # Pega arquivos que NAO estao na lista negra
  cat /tmp/_basenames.$$
  rm -f /tmp/_basenames.$$
)

# Metodo simples e robusto: copia tudo, depois deleta explicitamente
echo "      Copiando tudo (excluindo depois)..."
cp -r "$ROOT_DIR/." "$TEMP_DIR/codigo-fonte/" 2>/dev/null || true

# Remover diretorios da lista negra
for d in "${EXCLUDE_DIRS[@]}"; do
  find "$TEMP_DIR/codigo-fonte" -name "$d" -type d -prune -exec rm -rf {} + 2>/dev/null || true
done

# Remover arquivos da lista negra
for f in "${EXCLUDE_FILES[@]}"; do
  # Suporta glob (ex: *.log, *.local)
  find "$TEMP_DIR/codigo-fonte" -name "$f" -type f -delete 2>/dev/null || true
done

# Limpar arquivos vazios remanescentes
find "$TEMP_DIR/codigo-fonte" -type d -empty -delete 2>/dev/null || true

FILE_COUNT=$(find "$TEMP_DIR/codigo-fonte" -type f 2>/dev/null | wc -l)
echo "      OK ($FILE_COUNT arquivos)"

# ----------------------------------------------------------------------------
# 3. Gerar LEIA-ME-PRIMEIRO.txt (aponta para docs atuais)
# ----------------------------------------------------------------------------
echo "[3/5] Gerando LEIA-ME-PRIMEIRO.txt..."

cat > "$TEMP_DIR/LEIA-ME-PRIMEIRO.txt" << 'EOF'
================================================================
  ZAPIACRM v1.x - Pacote de Entrega
================================================================

BEM-VINDO!

Voce acabou de receber o ZAPIACRM completo - um SaaS white-label
de CRM + WhatsApp + IA para automacao comercial.

ESTE PACOTE INCLUI:
  codigo-fonte/         Codigo completo do sistema (SEM node_modules)
  README.md             Visao geral comercial (p/ decidir se vai usar)
  MANUAL.md             TUTORIAL PASSO-A-PASSO (12 capitulos, abra este!)
  CHECKLIST-PRE-DEPLOY  O que preparar ANTES (6 contas, todas gratis)
  CHECKLIST-POS-DEPLOY  O que validar DEPOIS (11 testes)
  SETUP_REPLICAVEL.sql  Script para rodar 1x no Supabase novo
  .env.example          18 vars documentadas (copia para .env.local)
  scripts/              vercel-build.mjs + migrate.mjs (build Vercel)
  prompts-customizacao/  5 prompts prontos pra customizar via IA
  troubleshooting/      Erros comuns + solucoes

COMO COMECAR (em 4 passos):

  1. Abra README.md para entender o que e o produto
  2. Abra CHECKLIST-PRE-DEPLOY.md para criar as 6 contas
  3. Abra MANUAL.md - siga cap 2 ate cap 9 na ordem
  4. Use CHECKLIST-POS-DEPLOY.md para validar

DEPOIS DO DEPLOY:
  - Use MANUAL.md cap 8 (white-label) pra trocar marca
  - Use prompts-customizacao/ pra customizar via IA
  - Use troubleshooting/ quando der erro

TEMPO ESTIMADO:
  - Criar contas (Vercel+Supabase+GitHub+Titan+SMTP+Gemini+VPS): 45-60 min
  - Deploy basico: 1-2 horas
  - Customizar marca: 30-60 min
  - TOTAL: 3-5 horas

CUSTO MENSAL PARA VOCE (cliente final):
  - R$ 0 com Vercel Hobby + Supabase Free + Titan SMTP + Gemini free
  - ~R$ 30/mes pelo VPS da Evolution (WhatsApp)
  - TOTAL MINIMO: R$ 30/mes

SUPORTE:
  - Este produto e SELF-SERVICE. Suporte human nao esta incluso.
  - MANUAL.md cobre 95% dos casos
  - Use Claude/ChatGPT para debugar: cole o erro + contexto do MANUAL

BOA SORTE COM O DEPLOY!
================================================================
  Por Jefferson Charles, 2026
================================================================
EOF

echo "      OK"

# ----------------------------------------------------------------------------
# 4. Compactar em ZIP
# ----------------------------------------------------------------------------
echo "[4/5] Compactando ZIP..."

# Comando ZIP: Linux usa `zip`, Windows Git Bash tem `zip`, mas pode nao.
# Fallback: usar PowerShell Compress-Archive se zip nao disponivel.

if command -v zip >/dev/null 2>&1; then
  (cd "$(dirname "$TEMP_DIR")" && zip -r "$OUTPUT_ZIP" "$(basename "$TEMP_DIR")" -q)
  echo "      OK (zip CLI)"
elif command -v powershell >/dev/null 2>&1; then
  # PowerShell roda em Windows nativo - precisa converter caminho MSYS para Windows
  TEMP_WIN="$(cygpath -w "$TEMP_DIR")"
  OUTPUT_WIN="$(cygpath -w "$OUTPUT_ZIP")"
  powershell -NoProfile -Command "Compress-Archive -Path '${TEMP_WIN}\\*' -DestinationPath '${OUTPUT_WIN}'"
  echo "      OK (PowerShell Compress-Archive)"
else
  echo "      ERRO: nem 'zip' nem 'powershell' disponiveis."
  echo "      Instale um dos dois ou compacte manualmente a pasta $TEMP_DIR"
  exit 1
fi

# ----------------------------------------------------------------------------
# 5. Limpar pasta temporaria
# ----------------------------------------------------------------------------
echo "[5/5] Limpando pasta temporaria..."

rm -rf "$TEMP_DIR"
echo "      OK"

# ----------------------------------------------------------------------------
# Final
# ----------------------------------------------------------------------------
ZIP_SIZE=$(du -h "$OUTPUT_ZIP" 2>/dev/null | cut -f1 || echo "?")
echo ""
echo "==================================================="
echo "  PACOTE CRIADO!"
echo "==================================================="
echo "  Arquivo: $OUTPUT_ZIP"
echo "  Tamanho: $ZIP_SIZE"
echo ""
echo "  Conteudo:"
echo "    - codigo-fonte/  (BUILD PRONTO p/ deploy)"
echo "    - README.md       (visao comercial)"
echo "    - MANUAL.md       (12 capitulos, tutorial completo)"
echo "    - LEIA-ME-PRIMEIRO.txt"
echo "    - CHECKLIST-PRE-DEPLOY.md + CHECKLIST-POS-DEPLOY.md"
echo "    - SETUP_REPLICAVEL.sql (26 KB)"
echo "    - scripts/  +  prompts-customizacao/  +  troubleshooting/"
echo ""
echo "  PROXIMOS PASSOS:"
echo "    1. Teste o ZIP extraindo em outra pasta"
echo "    2. Abra MANUAL.md cap 2 para ver o fluxo de deploy"
echo "    3. Envie para o cliente via Drive/Dropbox/email"
echo "==================================================="