#!/usr/bin/env bash
# Deploy da Minha Estante API usando Docker Compose.
#
# Executado na EC2 pelo pipeline (job "Deploy em produção"), mas também funciona
# localmente em qualquer máquina com Docker.
#
# Uso:
#   scripts/deploy.sh <tag>          # ex.: scripts/deploy.sh 3f2a9c1...  (SHA do commit)
#
# O que faz:
#   1. Guarda qual versão está no ar (para um possível rollback).
#   2. Baixa a imagem da nova versão no GHCR (docker pull).
#   3. Sobe o container com docker compose up -d.
#   4. Espera o /health responder (até HEALTH_TIMEOUT segundos).
#   5. Se falhar: rollback automático para a versão anterior e sai com erro
#      (o pipeline fica vermelho).
#   6. Se der certo: registra a versão e remove imagens antigas.
#
# Variáveis opcionais:
#   APP_DIR         pasta com o docker-compose.yml   (padrão: pasta acima deste script)
#   IMAGE_NAME      repositório da imagem             (padrão: definido no docker-compose.yml)
#   APP_PORT        porta da API no host              (padrão: 5000)
#   HEALTH_URL      URL verificada após o deploy      (padrão: http://localhost:$APP_PORT/health)
#   HEALTH_TIMEOUT  segundos de espera pelo health    (padrão: 60)
#
# Demonstração do rollback (força o health check a falhar):
#   HEALTH_URL=http://localhost:5000/nao-existe scripts/deploy.sh <tag>

set -euo pipefail

TAG="${1:?uso: deploy.sh <tag-da-imagem>}"
APP_DIR="${APP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
APP_PORT="${APP_PORT:-5000}"
HEALTH_URL="${HEALTH_URL:-http://localhost:${APP_PORT}/health}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-60}"
STATE_FILE="${APP_DIR}/.current_tag"

log() { echo "[deploy $(date '+%H:%M:%S')] $*"; }

# Sobe o serviço "api" na versão informada.
subir_versao() {
  local tag="$1"
  log "Baixando imagem (tag ${tag})..."
  IMAGE_TAG="$tag" docker compose pull api
  log "Subindo container (tag ${tag})..."
  IMAGE_TAG="$tag" docker compose up -d --no-build --remove-orphans api
}

# Retorna 0 quando o health check responde 200 dentro do tempo limite.
aguardar_health() {
  local inicio=$SECONDS
  log "Aguardando ${HEALTH_URL} (até ${HEALTH_TIMEOUT}s)..."
  while (( SECONDS - inicio < HEALTH_TIMEOUT )); do
    if curl -fsS --max-time 3 "$HEALTH_URL" >/dev/null 2>&1; then
      log "Health check OK após $((SECONDS - inicio))s."
      return 0
    fi
    sleep 2
  done
  log "Health check NÃO respondeu em ${HEALTH_TIMEOUT}s."
  return 1
}

cd "$APP_DIR"

ANTERIOR="$(cat "$STATE_FILE" 2>/dev/null || true)"
log "Versão no ar: ${ANTERIOR:-nenhuma}. Nova versão: ${TAG}."

# Se o pull falhar (tag inexistente, sem rede), o set -e encerra aqui
# e a versão que já estava no ar continua rodando, intacta.
subir_versao "$TAG"

if aguardar_health; then
  echo "$TAG" > "$STATE_FILE"
  log "Removendo imagens sem uso..."
  docker image prune -f >/dev/null
  log "Deploy da versão ${TAG} concluído com sucesso."
  exit 0
fi

log "Últimos logs do container com falha:"
docker compose logs --tail 30 api || true

if [[ -n "$ANTERIOR" && "$ANTERIOR" != "$TAG" ]]; then
  log "ROLLBACK: voltando para a versão ${ANTERIOR}..."
  subir_versao "$ANTERIOR"
  if HEALTH_URL="http://localhost:${APP_PORT}/health" aguardar_health; then
    log "Rollback concluído. A versão ${ANTERIOR} continua no ar."
  else
    log "ATENÇÃO: o rollback também falhou. Verifique o servidor."
  fi
else
  log "Não há versão anterior para rollback."
fi

exit 1
