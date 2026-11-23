.PHONY: install lint test build clean docker-build docker-run docker-stop docker-logs smoke

IMAGE ?= ghcr.io/diiegopaulino/minha-estante-api
TAG   ?= latest
URL   ?= http://localhost:5000

install:
	pip install -r requirements-dev.txt

lint:
	flake8 app tests --max-line-length=110

test:
	pytest --cov=app --cov-report=term-missing --cov-report=xml --cov-fail-under=80

build:
	mkdir -p dist
	tar -czf dist/minha-estante-api.tar.gz app requirements.txt

clean:
	rm -rf dist coverage.xml .pytest_cache .coverage

# ---- Docker ----
docker-build:
	docker build -t $(IMAGE):$(TAG) .

docker-run:
	docker compose up -d --build

docker-stop:
	docker compose down

docker-logs:
	docker compose logs -f

smoke:
	bash scripts/smoke_test.sh $(URL)
