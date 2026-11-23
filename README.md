# Minha Estante API — DevOps na Prática (PUCRS)

![CI/CD](https://github.com/diiegopaulino/minha-estante-devops/actions/workflows/ci-cd.yml/badge.svg)

API REST em Python/Flask para controle de livros (quero ler / lendo / lido), usada como base para aplicar práticas DevOps:

- **Fase 1:** integração contínua (GitHub Actions) e infraestrutura como código (Terraform na AWS).
- **Fase 2:** containerização (Docker), orquestração (Docker Compose), scripts de deploy e entrega contínua (CD) até a EC2.

## Estrutura

```
app/                          # código da API (Flask)
tests/                        # testes automatizados (pytest)
Dockerfile                    # imagem da API (multi-stage, gunicorn, não-root, healthcheck)
.dockerignore                 # o que fica fora da imagem
docker-compose.yml            # orquestração do container (porta, restart, limites, logs)
scripts/
  deploy.sh                   # deploy com health check e rollback automático
  smoke_test.sh               # validação funcional da API publicada
.github/workflows/ci-cd.yml   # pipeline CI/CD
infra/terraform/              # IaC: VPC, sub-rede, security group e EC2 com Docker
  modules/network/            # rede
  modules/compute/            # servidor de aplicação (user_data instala o Docker)
Makefile                      # comandos padronizados
```

## Rodando localmente

### Com Python

```bash
python -m venv .venv && source .venv/bin/activate
make install   # dependências
make lint      # análise estática (flake8)
make test      # testes + cobertura (mínimo 80%)
python -m app.main   # sobe a API em http://localhost:5000
```

### Com Docker

Pré-requisito: Docker (no Windows, o Docker Desktop aberto).

```bash
docker compose up -d --build      # ou: make docker-run
docker ps                         # STATUS deve mostrar "(healthy)"
curl http://localhost:5000/health
bash scripts/smoke_test.sh        # ou: make smoke
docker compose logs -f            # ou: make docker-logs
docker compose down               # ou: make docker-stop
```

## Endpoints

| Método | Rota | Descrição |
|---|---|---|
| GET | /health | Health check |
| GET | /livros?status= | Lista livros (filtro opcional) |
| POST | /livros | Cadastra livro (`titulo`, `autor`, `status`) |
| GET | /livros/{id} | Detalha livro |
| PATCH | /livros/{id} | Altera status |
| DELETE | /livros/{id} | Remove livro |

## Containerização

**Dockerfile**

- Base `python:3.12-slim`, build **multi-stage**: as dependências são instaladas num estágio e só o resultado vai para a imagem final.
- Servidor de produção **gunicorn** (1 worker, 4 threads). Como os livros ficam em memória, vários workers teriam dados diferentes cada um.
- Roda com **usuário não-root** (`appuser`, UID 10001).
- **HEALTHCHECK** consultando `/health` (com Python, sem precisar instalar curl).
- O SHA do commit é gravado na imagem (`APP_VERSION` e label `org.opencontainers.image.revision`).

**docker-compose.yml**

| Configuração | Valor | Motivo |
|---|---|---|
| `image` | `ghcr.io/diiegopaulino/minha-estante-api:${IMAGE_TAG}` | versão escolhida pelo deploy |
| `ports` | `${APP_PORT:-5000}:5000` | porta da API |
| `restart` | `unless-stopped` | volta sozinho após falha ou reboot |
| `healthcheck` | `/health` a cada 15 s | status `healthy`/`unhealthy` |
| `read_only` + `tmpfs /tmp` | sistema de arquivos somente leitura | endurecimento |
| `security_opt` | `no-new-privileges` | endurecimento |
| `deploy.resources.limits` | 256 MB, 0,5 CPU | a t3.micro tem 1 GB |
| `logging` | json-file, 3 × 10 MB | rotação de logs |

## Scripts de deploy

### `scripts/deploy.sh <tag>`

Executado na EC2 pelo pipeline, mas funciona em qualquer máquina com Docker.

1. Lê em `.current_tag` qual versão está no ar.
2. `docker compose pull` da imagem com a tag indicada (SHA do commit).
3. `docker compose up -d` com a nova versão.
4. Aguarda o `/health` responder (até 60 s).
5. Se falhar, faz **rollback** automático para a versão anterior e termina com erro (o pipeline fica vermelho).
6. Se der certo, grava a nova versão em `.current_tag` e remove imagens sem uso.

Variáveis opcionais: `APP_DIR`, `IMAGE_NAME`, `APP_PORT`, `HEALTH_URL`, `HEALTH_TIMEOUT`.

**Demonstrar o rollback** (força o health check a falhar; a versão anterior volta ao ar):

```bash
ssh -i labsuser.pem ubuntu@<IP>
cd /opt/minha-estante
echo "$TOKEN_GITHUB" | docker login ghcr.io -u <usuario> --password-stdin   # só se a imagem for privada
HEALTH_URL=http://localhost:5000/nao-existe HEALTH_TIMEOUT=10 bash scripts/deploy.sh <sha-de-outro-commit>
```

### `scripts/smoke_test.sh [URL]`

Valida a API publicada: `GET /health`, `POST /livros` e `GET /livros` (o livro criado precisa aparecer). Padrão: `http://localhost:5000`.

## Pipeline CI/CD

Arquivo: `.github/workflows/ci-cd.yml`.

```
push na main
  ├─ Lint (flake8)
  │    └─ Testes (pytest 3.11/3.12, cobertura ≥ 80%)
  │         └─ Build da imagem → Scan Trivy (CRITICAL falha) → teste do container → push GHCR (sha + latest)
  │              └─ Deploy em produção  ← aprovação manual (environment "production")
  │                   ├─ copia docker-compose.yml e deploy.sh para a EC2 (scp)
  │                   ├─ ssh → scripts/deploy.sh <sha>  (health check + rollback)
  │                   └─ smoke test na URL pública
  └─ Validar Terraform (fmt · init · validate)   [em paralelo; também é pré-requisito do deploy]
```

Em **pull requests** só roda a parte de CI (lint, testes, Terraform, build, scan e teste do container). Não há publicação nem deploy.

**Build once, deploy many:** a imagem testada e escaneada é exatamente a que vai para produção, identificada pelo SHA do commit.

### Configuração no GitHub

1. **Secrets** (Settings → Secrets and variables → Actions):

   | Nome | Valor |
   |---|---|
   | `EC2_HOST` | IP público da EC2 (sem `http://` e sem porta) |
   | `EC2_USER` | `ubuntu` |
   | `EC2_SSH_KEY` | conteúdo inteiro da chave privada (`labsuser.pem`) |

   Sem esses secrets o job de deploy é **pulado com um aviso** (o pipeline continua verde).

2. **Environment** (Settings → Environments → New environment): nome `production`, com **Required reviewers**. Todo deploy espera a aprovação.

3. **Imagem no GHCR:** o pipeline faz login temporário na EC2 com o `GITHUB_TOKEN`, então a imagem pode continuar privada. Deixá-la pública (perfil → Packages → `minha-estante-api` → Package settings) só é necessário para baixá-la sem login.

## Infraestrutura (Terraform)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # valores prontos para o AWS Academy
terraform init
terraform plan
terraform apply     # cria VPC, sub-rede, security group e EC2 com Docker
terraform output app_url
terraform destroy   # remove tudo (evita custos)
```

O `user_data` da EC2 instala Docker e Docker Compose, adiciona o usuário `ubuntu` ao grupo `docker` e cria `/opt/minha-estante`. Depois do `apply`, aguarde 2 a 3 minutos antes do primeiro deploy.

> **AWS Academy:** as credenciais expiram a cada sessão e o IP público da EC2 muda quando o lab reinicia. Atualize o secret `EC2_HOST` sempre que isso acontecer.

## Segurança, monitoramento e logs

- Segredos (host, usuário, chave SSH) apenas em GitHub Secrets; o token do GHCR é temporário e o `docker logout` roda ao final do deploy.
- Imagem sem root, sistema de arquivos somente leitura e scan de vulnerabilidades (Trivy) no pipeline.
- EC2 com disco criptografado e IMDSv2 obrigatório (Fase 1).
- Healthcheck no container, verificação pós-deploy e smoke test.
- Logs de acesso e de erro do gunicorn em stdout: `docker logs minha-estante-api` (com rotação).
