"""Minha Estante API — API REST simples para controle de livros lidos/a ler."""
import os

from flask import Flask, jsonify, request

STATUS_VALIDOS = {"quero-ler", "lendo", "lido"}


def create_app():
    app = Flask(__name__)
    livros = {}
    proximo_id = {"valor": 1}

    @app.get("/health")
    def health():
        # APP_VERSION é o SHA do commit, gravado na imagem Docker pelo pipeline.
        return jsonify(status="ok", versao=os.environ.get("APP_VERSION", "dev")[:7]), 200

    @app.get("/livros")
    def listar():
        status = request.args.get("status")
        itens = list(livros.values())
        if status:
            itens = [livro for livro in itens if livro["status"] == status]
        return jsonify(itens), 200

    @app.post("/livros")
    def criar():
        dados = request.get_json(silent=True) or {}
        titulo = (dados.get("titulo") or "").strip()
        autor = (dados.get("autor") or "").strip()
        status = dados.get("status", "quero-ler")
        if not titulo or not autor:
            return jsonify(erro="'titulo' e 'autor' são obrigatórios"), 400
        if status not in STATUS_VALIDOS:
            return jsonify(erro=f"status deve ser um de {sorted(STATUS_VALIDOS)}"), 400
        livro = {"id": proximo_id["valor"], "titulo": titulo, "autor": autor, "status": status}
        livros[livro["id"]] = livro
        proximo_id["valor"] += 1
        return jsonify(livro), 201

    @app.get("/livros/<int:livro_id>")
    def obter(livro_id):
        livro = livros.get(livro_id)
        if not livro:
            return jsonify(erro="livro não encontrado"), 404
        return jsonify(livro), 200

    @app.patch("/livros/<int:livro_id>")
    def atualizar_status(livro_id):
        livro = livros.get(livro_id)
        if not livro:
            return jsonify(erro="livro não encontrado"), 404
        status = (request.get_json(silent=True) or {}).get("status")
        if status not in STATUS_VALIDOS:
            return jsonify(erro=f"status deve ser um de {sorted(STATUS_VALIDOS)}"), 400
        livro["status"] = status
        return jsonify(livro), 200

    @app.delete("/livros/<int:livro_id>")
    def remover(livro_id):
        if livros.pop(livro_id, None) is None:
            return jsonify(erro="livro não encontrado"), 404
        return "", 204

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
