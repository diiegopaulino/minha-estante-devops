# syntax=docker/dockerfile:1
# Imagem da Minha Estante API.
# Build multi-stage: o primeiro estágio instala as dependências e o segundo
# copia só o resultado, deixando a imagem final menor e sem ferramentas de build.

# ---------- Estágio 1: dependências ----------
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- Estágio 2: imagem final ----------
FROM python:3.12-slim

# Versão (SHA do commit) gravada como metadado da imagem pelo pipeline.
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="minha-estante-api" \
      org.opencontainers.image.source="https://github.com/diiegopaulino/minha-estante-devops" \
      org.opencontainers.image.revision="${APP_VERSION}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION}

# Usuário sem privilégios: o processo não roda como root dentro do container.
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app
COPY --from=builder /install /usr/local
COPY app ./app

USER appuser
EXPOSE 5000

# O Docker marca o container como "healthy" quando /health responde 200.
# Usa Python (já presente na imagem) para não precisar instalar curl.
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import sys, urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=2).status == 200 else 1)"

# gunicorn é o servidor WSGI de produção (o servidor do Flask é só para desenvolvimento).
# 1 worker com 4 threads: os livros ficam em memória, então vários workers
# teriam dados diferentes cada um. Logs de acesso e de erro vão para stdout/stderr.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "4", \
     "--worker-tmp-dir", "/tmp", "--access-logfile", "-", "--error-logfile", "-", "app.main:app"]
