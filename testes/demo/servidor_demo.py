# ================================================================
# Servidor do MODO DEMONSTRAÇÃO da Central do Financeiro
#
#   python testes\demo\servidor_demo.py
#   abrir: http://localhost:8000/index.html#/financeiro/central
#
# - Serve os arquivos do sistema só para este computador (127.0.0.1).
# - Em toda página HTML, injeta testes/demo/demo.js ANTES de qualquer script:
#   ele responde no lugar do Supabase com dados fictícios.
# - Manda a regra de segurança Content-Security-Policy "connect-src" sem o
#   Supabase: mesmo que algo escape do simulador, o navegador BLOQUEIA a conexão
#   com o banco real.
# - Ctrl+C para parar.
# ================================================================
import os, sys
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

AQUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(AQUI))
PORTA = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
DEMO_JS = os.path.join(AQUI, "demo.js")

CSP = ("connect-src 'self' blob: data: https://cdn.jsdelivr.net https://fonts.googleapis.com https://fonts.gstatic.com "
       "https://api.open-meteo.com https://geocoding-api.open-meteo.com")


class Demo(SimpleHTTPRequestHandler):
    def log_message(self, *a): pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Security-Policy", CSP)
        super().end_headers()

    def do_GET(self):
        caminho = self.path.split("?")[0].split("#")[0]
        if caminho == "/__demo/demo.js":
            return self.enviar(open(DEMO_JS, "rb").read(), "application/javascript; charset=utf-8")
        if caminho == "/":
            caminho = "/index.html"
        if caminho.endswith(".html"):
            arq = os.path.normpath(os.path.join(REPO, caminho.lstrip("/")))
            if not arq.startswith(REPO) or not os.path.isfile(arq):
                return self.send_error(404)
            html = open(arq, encoding="utf-8").read()
            i = html.lower().find("<head>")
            tag = '<script src="/__demo/demo.js"></script>'
            html = html[:i + 6] + tag + html[i + 6:] if i >= 0 else tag + html
            return self.enviar(html.encode("utf-8"), "text/html; charset=utf-8")
        return super().do_GET()

    def enviar(self, dados, tipo):
        self.send_response(200)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(dados)))
        self.end_headers()
        self.wfile.write(dados)


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("127.0.0.1", PORTA), partial(Demo, directory=REPO))
    print(f"MODO DEMONSTRAÇÃO no ar: http://localhost:{PORTA}/index.html#/financeiro/central")
    print("PDFs para arrastar:", os.path.join(AQUI, "pdfs-para-arrastar"))
    print("Ctrl+C para parar.")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
