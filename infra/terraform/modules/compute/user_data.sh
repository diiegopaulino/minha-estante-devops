#!/bin/bash
# Prepara a instância para receber a aplicação (deploy automatizado virá na Fase 2).
set -euo pipefail
apt-get update -y
apt-get install -y python3 python3-pip python3-venv git
mkdir -p /opt/minha-estante
echo "APP_PORT=${app_port}" > /opt/minha-estante/.env
