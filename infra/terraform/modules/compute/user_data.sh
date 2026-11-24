#!/bin/bash
# Prepara a EC2 para receber os deploys em container (Fase 2).
# Executado uma única vez, como root, na primeira inicialização da instância.
# Obs.: arquivo processado pelo templatefile do Terraform; ${app_port} é substituído.
set -euo pipefail

# Docker Engine + plugin Docker Compose (pacotes oficiais do Ubuntu 24.04).
apt-get update -y
apt-get install -y docker.io docker-compose-v2 curl
systemctl enable --now docker

# Permite que o usuário ubuntu (usado pelo pipeline via SSH) rode docker sem sudo.
usermod -aG docker ubuntu

# Pasta da aplicação: o pipeline copia para cá o docker-compose.yml e o deploy.sh.
mkdir -p /opt/minha-estante/scripts
echo "APP_PORT=${app_port}" > /opt/minha-estante/.env
chown -R ubuntu:ubuntu /opt/minha-estante
