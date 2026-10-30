# ================================================================
# Teste de leitura de comprovantes (Módulo 2) com o Cloudflare Workers AI
# Ideali Laboratório · Central do Financeiro
#
# Roda no SEU computador. O token NÃO fica neste arquivo nem aparece na tela.
#
# 1. Ponha as imagens (JPG/PNG/WEBP) em testes/comprovantes/
#    (a pasta está no .gitignore: nunca sobe para o GitHub).
#    PDF fica de fora: PDF com texto é lido pelo leitor local, sem IA.
# 2. Crie testes/comprovantes/gabarito.csv com o valor certo de cada um,
#    separado por ponto e vírgula:
#        arquivo;valor;data;id_pix
#        pix_ana.jpg;1.850,00;05/10/2026;E00000000202610051234abcdEFGH5678
#        foto_boleto.jpg;320,50;07/10/2026;
#    (id_pix vazio se o comprovante não tiver ID)
# 3. No PowerShell, sem colar o token em lugar nenhum:
#        $env:CF_ACCOUNT_ID = "id-da-conta"
#        $env:CF_AI_TOKEN   = Read-Host "Token Workers AI" -AsSecureString | % { [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) }
#        python testes\teste_visao_cloudflare.py
#    (ou ponha CF_ACCOUNT_ID e CF_AI_TOKEN no .env, que também é ignorado pelo git)
#
# Critério (por modelo):
#   valor  100% certo: qualquer erro reprova
#   data   pelo menos 95% certa
#   ID Pix pelo menos 95% certo (só conta os que têm ID no gabarito)
# "Não leu" conta como erro.
#
# Resultado detalhado: testes/comprovantes/resultado.csv (fica só no computador).
# ================================================================
import base64, csv, io, json, os, re, sys, time, urllib.request, urllib.error
from PIL import Image, ImageOps

AQUI = os.path.dirname(os.path.abspath(__file__))
PASTA = os.path.join(AQUI, "comprovantes")
RAIZ = os.path.dirname(AQUI)
MODELOS = ["@cf/meta/llama-3.2-11b-vision-instruct", "@cf/mistralai/mistral-small-3.1-24b-instruct"]
EXTS = (".jpg", ".jpeg", ".png", ".webp")

PROMPT = (
    "Este é um comprovante de pagamento brasileiro (Pix, TED ou boleto). "
    "Leia o VALOR pago, a DATA do pagamento e o ID da transação Pix (código E2E, começa com a letra E e tem 32 caracteres). "
    "Responda SOMENTE com um JSON, sem texto antes ou depois, neste formato: "
    '{"valor": "1.234,56", "data": "DD/MM/AAAA", "id_pix": "E..."} '
    "Use vazio (\"\") no campo que não existir. Não invente: se não conseguir ler, deixe vazio."
)


def config():
    env = {}
    p = os.path.join(RAIZ, ".env")
    if os.path.exists(p):
        for linha in open(p, encoding="utf-8"):
            m = re.match(r"\s*(CF_ACCOUNT_ID|CF_AI_TOKEN)\s*=\s*(\S+)", linha)
            if m: env[m.group(1)] = m.group(2).strip("\"'")
    acc = os.environ.get("CF_ACCOUNT_ID") or env.get("CF_ACCOUNT_ID")
    tok = os.environ.get("CF_AI_TOKEN") or env.get("CF_AI_TOKEN")
    if not acc or not tok:
        sys.exit("Falta CF_ACCOUNT_ID ou CF_AI_TOKEN (variável de ambiente ou .env). Veja o topo deste arquivo.")
    return acc, tok


def post(url, tok, corpo):
    req = urllib.request.Request(url, data=json.dumps(corpo).encode(), method="POST",
                                 headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read().decode())
        except Exception: return e.code, {}


def preparar(caminho):
    # gira pela orientação da foto e reduz para no máximo 1600 px (menos custo, mesma leitura)
    im = ImageOps.exif_transpose(Image.open(caminho)).convert("RGB")
    im.thumbnail((1600, 1600))
    buf = io.BytesIO(); im.save(buf, "JPEG", quality=90)
    return buf.getvalue()


def ler(acc, tok, modelo, jpg, aceitou):
    url_dados = "data:image/jpeg;base64," + base64.b64encode(jpg).decode()
    st, j = post(f"https://api.cloudflare.com/client/v4/accounts/{acc}/ai/v1/chat/completions", tok, {
        "model": modelo, "temperature": 0, "max_tokens": 300,
        "messages": [{"role": "user", "content": [{"type": "text", "text": PROMPT},
                                                  {"type": "image_url", "image_url": {"url": url_dados}}]}]})
    if st == 200 and j.get("choices"):
        return j["choices"][0]["message"].get("content") or "", j.get("usage") or {}
    erro = json.dumps(j)[:300]
    # Llama 3.2 Vision: licença da Meta precisa ser aceita uma vez por conta
    if "llama-3.2" in modelo and "agree" in erro.lower() and not aceitou.get(modelo):
        post(f"https://api.cloudflare.com/client/v4/accounts/{acc}/ai/run/{modelo}", tok, {"prompt": "agree"})
        aceitou[modelo] = True
        return ler(acc, tok, modelo, jpg, aceitou)
    # Llama: formato antigo, imagem como lista de bytes
    if "llama-3.2" in modelo:
        st, j = post(f"https://api.cloudflare.com/client/v4/accounts/{acc}/ai/run/{modelo}", tok,
                     {"prompt": PROMPT, "image": list(jpg), "max_tokens": 300, "temperature": 0})
        if st == 200 and j.get("success"):
            return j["result"].get("response") or "", j["result"].get("usage") or {}
        erro = json.dumps(j)[:300]
    raise RuntimeError(f"HTTP {st}: {erro}")


def valor_centavos(v):
    if v is None: return None
    if isinstance(v, (int, float)): return round(float(v) * 100)
    s = re.sub(r"[^\d,.-]", "", str(v))
    if not s: return None
    if "," in s: s = s.replace(".", "").replace(",", ".")      # 1.234,56
    elif s.count(".") > 1: s = s.replace(".", "")               # 1.234.567
    try: return round(float(s) * 100)
    except ValueError: return None


def data_norm(v):
    s = str(v or "").strip()
    m = re.search(r"(\d{4})-(\d{1,2})-(\d{1,2})", s)
    if m: return "%02d/%02d/%s" % (int(m.group(3)), int(m.group(2)), m.group(1))
    m = re.search(r"(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})", s)
    if m:
        a = m.group(3); a = "20" + a if len(a) == 2 else a
        return "%02d/%02d/%s" % (int(m.group(1)), int(m.group(2)), a)
    return ""


def id_norm(v):
    return re.sub(r"[^A-Za-z0-9]", "", str(v or "")).upper()


def extrair_json(txt):
    m = re.search(r"\{.*\}", txt or "", re.S)
    if not m: return {}
    try: return json.loads(m.group(0))
    except json.JSONDecodeError: return {}


def main():
    acc, tok = config()
    gab_p = os.path.join(PASTA, "gabarito.csv")
    if not os.path.exists(gab_p): sys.exit("Falta testes/comprovantes/gabarito.csv (veja o topo deste arquivo).")
    with open(gab_p, encoding="utf-8-sig", newline="") as f:
        gab = {r["arquivo"].strip(): r for r in csv.DictReader(f, delimiter=";")}
    arquivos = [a for a in sorted(gab) if a.lower().endswith(EXTS) and os.path.exists(os.path.join(PASTA, a))]
    faltam = [a for a in gab if a not in arquivos]
    if faltam: print("Fora do teste (não é imagem ou não achei o arquivo):", ", ".join(faltam))
    if not arquivos: sys.exit("Nenhuma imagem do gabarito encontrada em testes/comprovantes/.")
    modelos = sys.argv[1:] or MODELOS

    linhas, aceitou = [], {}
    for modelo in modelos:
        ok = {"valor": [0, 0], "data": [0, 0], "id": [0, 0]}
        tokens_in = tokens_out = 0
        print(f"\n== {modelo} ({len(arquivos)} comprovantes)")
        for a in arquivos:
            g = gab[a]
            jpg = preparar(os.path.join(PASTA, a))
            t0 = time.time()
            try:
                txt, uso = ler(acc, tok, modelo, jpg, aceitou); erro = ""
            except Exception as e:
                txt, uso, erro = "", {}, str(e)[:200]
            tokens_in += int(uso.get("prompt_tokens") or 0); tokens_out += int(uso.get("completion_tokens") or 0)
            lido = extrair_json(txt)
            certo_v = valor_centavos(g.get("valor"))
            lido_v = valor_centavos(lido.get("valor"))
            r_v = lido_v is not None and lido_v == certo_v
            r_d = data_norm(lido.get("data")) == data_norm(g.get("data")) != ""
            tem_id = bool(id_norm(g.get("id_pix")))
            r_i = id_norm(lido.get("id_pix")) == id_norm(g.get("id_pix")) if tem_id else None
            ok["valor"][0] += r_v; ok["valor"][1] += 1
            ok["data"][0] += r_d; ok["data"][1] += 1
            if tem_id: ok["id"][0] += r_i; ok["id"][1] += 1
            marca = lambda b: "ok" if b else ("-" if b is None else "ERRO")
            print(f"  {a:<32} valor {marca(r_v):<4} data {marca(r_d):<4} id {marca(r_i):<4} {time.time() - t0:4.1f}s {erro}")
            linhas.append({"modelo": modelo, "arquivo": a, "valor_certo": g.get("valor"), "valor_lido": lido.get("valor", ""),
                           "data_certa": g.get("data"), "data_lida": lido.get("data", ""), "id_certo": g.get("id_pix"),
                           "id_lido": lido.get("id_pix", ""), "valor_ok": r_v, "data_ok": r_d, "id_ok": r_i,
                           "erro": erro, "resposta": (txt or "")[:300]})

        pct = lambda k: 100.0 * ok[k][0] / ok[k][1] if ok[k][1] else None
        aprov_v = ok["valor"][0] == ok["valor"][1]
        aprov_d = (pct("data") or 0) >= 95
        aprov_i = ok["id"][1] == 0 or pct("id") >= 95
        print(f"  valor: {ok['valor'][0]}/{ok['valor'][1]} {'OK' if aprov_v else 'REPROVA (precisa 100%)'}")
        print(f"  data:  {ok['data'][0]}/{ok['data'][1]} ({pct('data'):.0f}%) {'OK' if aprov_d else 'REPROVA (precisa 95%)'}")
        if ok["id"][1]:
            print(f"  ID:    {ok['id'][0]}/{ok['id'][1]} ({pct('id'):.0f}%) {'OK' if aprov_i else 'REPROVA (precisa 95%)'}")
        else:
            print("  ID:    nenhum comprovante com ID no gabarito (não avaliado)")
        print(f"  tokens: {tokens_in} de entrada, {tokens_out} de saída")
        print(f"  >>> {'APROVADO' if aprov_v and aprov_d and aprov_i else 'REPROVADO'}")

    saida = os.path.join(PASTA, "resultado.csv")
    with open(saida, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(linhas[0]), delimiter=";"); w.writeheader(); w.writerows(linhas)
    print("\nDetalhes em", saida)


if __name__ == "__main__":
    main()
