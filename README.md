# Minha Estante API — DevOps na Prática (PUCRS)

![CI](https://github.com/diiegopaulino/minha-estante-devops/actions/workflows/ci.yml/badge.svg)

API REST em Python/Flask para controle de livros (quero ler / lendo / lido), usada como base para aplicar práticas DevOps: integração contínua com GitHub Actions e infraestrutura como código com Terraform (AWS).

## Estrutura

```
app/                      # código da API (Flask)
tests/                    # testes automatizados (pytest)
.github/workflows/ci.yml  # pipeline de CI
infra/terraform/          # IaC: VPC, sub-rede, security group e EC2
  modules/network/        # rede
  modules/compute/        # servidor de aplicação
Makefile                  # comandos de build padronizados
```

## Rodando localmente

```bash
python -m venv .venv && source .venv/bin/activate
make install   # dependências
make lint      # análise estática (flake8)
make test      # testes + cobertura (mínimo 80%)
make build     # gera dist/minha-estante-api.tar.gz
python -m app.main   # sobe a API em http://localhost:5000
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

## Pipeline de CI

Disparado em push/PR na `main`: **Lint → Testes (Python 3.11 e 3.12) → Build (artefato)**, e em paralelo **Validação do Terraform** (`fmt`, `init`, `validate`).

## Infraestrutura (Terraform)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # ajuste seu IP
terraform init
terraform plan
terraform apply     # cria os recursos na AWS
terraform destroy   # remove tudo (evita custos)
```
