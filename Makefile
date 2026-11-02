.PHONY: install lint test build clean

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
