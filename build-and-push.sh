#!/bin/bash
# =============================================================================
# ZAPIACRM - Build + Push DEFINITIVO v2 (com debug)
# =============================================================================

set -e

DOCKERHUB_USER="jeffersoncharles1007"
DOCKERHUB_TOKEN="dckr_pat_nF8i80VE2dXMC8AZ6Nu1TXR3F6w"
IMAGE_NAME="zapiacrm-app"

echo "============================================================"
echo "  ZAPIACRM - Build & Push Docker Image"
echo "============================================================"

# 1. Limpar
echo ""
echo "[1/6] Limpando..."
cd /root
rm -rf /opt/zapiacrm
docker ps -a 2>/dev/null | grep zapiacrm | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
docker images 2>/dev/null | grep zapiacrm | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

# 2. Login no Docker Hub (BEFORE clone pra cachear credenciais)
echo ""
echo "[2/6] Login Docker Hub..."
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin
docker info 2>&1 | grep -i "username\|registry" | head -5

# 3. Clone (SEM submódulos)
echo ""
echo "[3/6] Clonando repositorio..."
git clone --depth 1 --single-branch --no-tags https://github.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template.git /opt/zapiacrm
cd /opt/zapiacrm
ls -la Dockerfile package.json

# 4. Configurar git pra nao usar LFS ou hooks
echo ""
echo "[4/6] Configurando git..."
git lfs uninstall 2>/dev/null || true
git config --global --add safe.directory /opt/zapiacrm

# 5. Build com output detalhado
echo ""
echo "[5/6] Building imagem (~5-8 min)..."
echo "Log completo em /tmp/zapiacrm-build.log"
docker build -t "$DOCKERHUB_USER/$IMAGE_NAME:latest" -t "$DOCKERHUB_USER/$IMAGE_NAME:v1.0" . 2>&1 | tee /tmp/zapiacrm-build.log | tail -30
BUILD_EXIT=${PIPESTATUS[0]}

if [ $BUILD_EXIT -ne 0 ]; then
    echo ""
    echo "============================================================"
    echo "  BUILD FALHOU! Veja: cat /tmp/zapiacrm-build.log"
    echo "============================================================"
    tail -50 /tmp/zapiacrm-build.log
    exit 1
fi

# 6. Push
echo ""
echo "[6/6] Pushing pro Docker Hub..."
docker push "$DOCKERHUB_USER/$IMAGE_NAME:latest 2>&1 | tail -5
docker push "$DOCKERHUB_USER/$IMAGE_NAME:v1.0" 2>&1 | tail -5

echo ""
echo "============================================================"
echo "  IMAGEM PUBLICADA COM SUCESSO!"
echo "============================================================"
echo ""
echo "https://hub.docker.com/r/$DOCKERHUB_USER/$IMAGE_NAME/tags"