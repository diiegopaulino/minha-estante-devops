#!/usr/bin/env bash
# Smoke test da Minha Estante API publicada.
#
# Executado pelo pipeline logo após o deploy, contra a URL pública da EC2.
# Também pode ser usado localmente.
#
# Uso:
#   scripts/smoke_test.sh [URL_BASE]        # padrão: http://localhost:5000
#
# Verifica:
#   1. GET  /health   -> 200 e {"status": "ok"}
#   2. POST /livros   -> 201 (cria um livro de teste)
#   3. GET  /livros   -> 200 e o livro criado aparece na lista
#
# Sai com código diferente de zero na primeira verificação que falhar.

set -euo pipefail

BASE_URL="${1:-http://localhost:5000}"
BASE_URL="${BASE_URL%/}"
TENTATIVAS="${SMOKE_RETRIES:-10}"

log()   { echo "[smoke] $*"; }
falha() { echo "[smoke] FALHOU: $*" >&2; exit 1; }

# 1. Health (com novas tentativas, pois a porta pode levar alguns segundos para abrir).
log "GET ${BASE_URL}/health"
for ((i = 1; i <= TENTATIVAS; i++)); do
  if corpo="$(curl -fsS --max-time 5 "${BASE_URL}/health")"; then
    break
  fi
  [[ $i -eq $TENTATIVAS ]] && falha "/health não respondeu após ${TENTATIVAS} tentativas"
  sleep 3
done
grep -q '"status": *"ok"' <<<"$corpo" || falha "/health respondeu algo inesperado: ${corpo}"
log "OK -> ${corpo}"

# 2. Criação de livro.
TITULO="Smoke test $(date +%s)"
log "POST ${BASE_URL}/livros (\"${TITULO}\")"
resposta="$(curl -sS --max-time 5 -w $'\n%{http_code}' -X POST "${BASE_URL}/livros" \
  -H "Content-Type: application/json" \
  -d "{\"titulo\": \"${TITULO}\", \"autor\": \"Pipeline CI/CD\", \"status\": \"lido\"}")"
codigo="${resposta##*$'\n'}"
corpo="${resposta%$'\n'*}"
[[ "$codigo" == "201" ]] || falha "POST /livros retornou HTTP ${codigo}: ${corpo}"
log "OK -> HTTP 201 ${corpo}"

# 3. Listagem contendo o livro criado.
log "GET ${BASE_URL}/livros"
corpo="$(curl -fsS --max-time 5 "${BASE_URL}/livros")" || falha "GET /livros falhou"
grep -q "$TITULO" <<<"$corpo" || falha "o livro criado não aparece na listagem"
log "OK -> livro encontrado na listagem"

log "Todas as verificações passaram em ${BASE_URL}"
