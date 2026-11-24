import pytest

from app.main import create_app


@pytest.fixture
def client():
    app = create_app()
    app.config["TESTING"] = True
    return app.test_client()


def criar_livro(client, **extra):
    payload = {"titulo": "Dom Casmurro", "autor": "Machado de Assis", **extra}
    return client.post("/livros", json=payload)


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok", "versao": "dev"}


def test_health_mostra_versao_do_commit(client, monkeypatch):
    monkeypatch.setenv("APP_VERSION", "3f2a9c1d8e7b6a5f")
    resp = client.get("/health")
    assert resp.get_json()["versao"] == "3f2a9c1"


def test_criar_livro(client):
    resp = criar_livro(client)
    assert resp.status_code == 201
    assert resp.get_json()["status"] == "quero-ler"


def test_criar_livro_sem_titulo_retorna_400(client):
    resp = client.post("/livros", json={"autor": "Alguém"})
    assert resp.status_code == 400


def test_criar_livro_status_invalido_retorna_400(client):
    resp = criar_livro(client, status="abandonado")
    assert resp.status_code == 400


def test_listar_e_filtrar_por_status(client):
    criar_livro(client)
    criar_livro(client, titulo="1984", autor="George Orwell", status="lido")
    assert len(client.get("/livros").get_json()) == 2
    lidos = client.get("/livros?status=lido").get_json()
    assert [livro["titulo"] for livro in lidos] == ["1984"]


def test_obter_livro_inexistente_retorna_404(client):
    assert client.get("/livros/999").status_code == 404


def test_atualizar_status(client):
    livro_id = criar_livro(client).get_json()["id"]
    resp = client.patch(f"/livros/{livro_id}", json={"status": "lendo"})
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "lendo"


def test_remover_livro(client):
    livro_id = criar_livro(client).get_json()["id"]
    assert client.delete(f"/livros/{livro_id}").status_code == 204
    assert client.get(f"/livros/{livro_id}").status_code == 404
