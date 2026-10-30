# Teste de negacao da 052 (Inove: so acompanhamento) NO BANCO REAL.
#
# Rode DEPOIS de aplicar a 052:   python testes/teste_negacao_inove_052.py
#
# O que faz:
#   1. cria um usuario inove TEMPORARIO (e-mail @exemplo.invalid, senha aleatoria)
#   2. entra com ele e tenta ler TODAS as tabelas/views do schema public (lista vem do
#      proprio banco): fora pagamento_aportes, vencimento_mensal e as 3 views inove_*_v,
#      tudo tem que voltar vazio
#   3. confere que as views so trazem os campos permitidos (sem CPF, endereco, comissao...)
#   4. tenta gravar onde nao pode (cadastro, controle mensal direto) e ler buckets proibidos
#   5. testa o registro de clique no WhatsApp (e apaga a linha de teste)
#   6. regra "ativo OU saldo diferente de zero": cria 2 clientes TEMPORARIOS inativos
#      (reg 990001+, nome "TESTE 052 ... (apagar)"): um com divida de R$ 123,45 em jan/2099
#      (mes fora de qualquer mes real) que TEM que aparecer, e um zerado que NAO pode aparecer
#   7. APAGA tudo que criou (clientes, linha do controle mensal, auditoria dessa linha,
#      cliques e o usuario temporario), mesmo se algo der errado no meio
# Nao altera nenhum dado de cliente real. Precisa de SUPABASE_SECRET_KEY no .env (raiz do repo).
import json, os, re, secrets, sys, urllib.request, urllib.error

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = "https://alqhhgysvehtgkwsxeok.supabase.co"
SECRET = next((l.split("=", 1)[1].strip() for l in open(os.path.join(RAIZ, ".env"), encoding="utf-8")
               if l.startswith("SUPABASE_SECRET_KEY=")), None)
PUB = re.search(r"SUPABASE_PUBLISHABLE_KEY\s*=\s*'([^']+)'", open(os.path.join(RAIZ, "auth.js"), encoding="utf-8").read()).group(1)
if not SECRET:
    sys.exit("Falta SUPABASE_SECRET_KEY no .env")

PERMITIDAS = {"pagamento_aportes", "vencimento_mensal", "inove_clientes_v", "inove_controle_mensal_v", "inove_config_v"}
CAMPOS_CLIENTES_V = {"reg", "nome", "tel_wa", "ativo", "saldo", "credito", "vencimento_mais_antigo", "dias_atraso"}
PROIBIDOS_EM_VIEW = {"cpf", "cro", "end_str", "bairro", "cidade", "uf", "cep", "email", "tel", "obs",
                     "valor_pago_comissionado", "extrato_url", "user_id"}

def http(metodo, caminho, chave, token=None, corpo=None, extra=None):
    h = {"apikey": chave, "Authorization": "Bearer " + (token or chave), "Content-Type": "application/json"}
    h.update(extra or {})
    req = urllib.request.Request(URL + caminho, method=metodo, headers=h,
                                 data=json.dumps(corpo).encode("utf-8") if corpo is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            txt = r.read().decode("utf-8")
            return r.status, (json.loads(txt) if txt else None)
    except urllib.error.HTTPError as e:
        txt = e.read().decode("utf-8", "replace")
        try: return e.code, json.loads(txt)
        except Exception: return e.code, txt

resultados = []
def checa(nome, ok, detalhe=""):
    resultados.append((ok, nome, detalhe))
    print(("  OK   " if ok else "  FALHOU ") + nome + (("  -> " + detalhe) if detalhe else ""))

# ── dono e lista de tabelas (com a chave secreta) ──
st, cfg = http("GET", "/rest/v1/ideali_config?select=dono_id", SECRET)
dono_id = cfg[0]["dono_id"] if st == 200 and cfg else sys.exit("Nao achei ideali_config.dono_id: %s %s" % (st, cfg))
st, api = http("GET", "/rest/v1/", SECRET, extra={"Accept": "application/openapi+json"})
tabelas = sorted(k.strip("/") for k in (api.get("paths") or {}) if k.count("/") == 1 and not k.startswith("/rpc/") and k != "/")
if not tabelas:
    sys.exit("Nao consegui listar as tabelas (%s)" % st)
print("Tabelas/views expostas no banco: %d" % len(tabelas))

# python testes/teste_negacao_inove_052.py --usuario-real inove3dlab@gmail.com
#   -> roda tudo com o login REAL da Inove (nao cria nem apaga usuario)
USUARIO_REAL = sys.argv[sys.argv.index("--usuario-real") + 1].strip().lower() if "--usuario-real" in sys.argv else None
tok = None
email = "teste-inove-052-%s@exemplo.invalid" % secrets.token_hex(4)
senha = secrets.token_urlsafe(24)
uid = None
regs_teste = []  # clientes temporarios criados (apagados no fim)

def limpar_clientes_teste():
    for r in regs_teste:
        for filtro in ("depois->>cliente_reg=eq.%s" % r, "antes->>cliente_reg=eq.%s" % r):
            http("DELETE", "/rest/v1/fin_auditoria?tabela=eq.controle_mensal&" + filtro, SECRET)
        http("DELETE", "/rest/v1/inove_whatsapp_cliques?cliente_reg=eq.%s" % r, SECRET)
        http("DELETE", "/rest/v1/controle_mensal?cliente_reg=eq.%s" % r, SECRET)
        st, _ = http("DELETE", "/rest/v1/cadastro_clientes?reg=eq.%s" % r, SECRET)
        print("Cliente temporario %s apagado" % r if st in (200, 204) else "ATENCAO: nao apaguei o cliente temporario reg %s (%s)" % (r, st))

try:
    # ── 0) dois clientes inativos temporarios: com divida (aparece) e zerado (some) ──
    livres = [r for r in range(990001, 990100)]
    _, usados = http("GET", "/rest/v1/cadastro_clientes?select=reg&reg=gte.990001&reg=lte.990099", SECRET)
    usados = {u["reg"] for u in (usados or [])}
    livres = [r for r in livres if r not in usados][:2]
    REG_DIVIDA, REG_ZERADO = livres
    for reg, nome, tel in ((REG_DIVIDA, "TESTE 052 inativo com divida (apagar)", "(21) 90000-0001"),
                           (REG_ZERADO, "TESTE 052 inativo zerado (apagar)", None)):
        st, d = http("POST", "/rest/v1/cadastro_clientes", SECRET, corpo=
                     {"reg": reg, "nome": nome, "status": "inativo", "tel": tel, "user_id": dono_id})
        if st not in (200, 201):
            sys.exit("Nao criei o cliente temporario %s: %s %s" % (reg, st, d))
        regs_teste.append(reg)
    st, d = http("POST", "/rest/v1/controle_mensal", SECRET, corpo=
                 {"cliente_reg": REG_DIVIDA, "mes": 0, "ano": 2099, "valor_mes": 123.45, "valor_pago": 0, "user_id": dono_id})
    if st not in (200, 201):
        sys.exit("Nao criei a divida de teste: %s %s" % (st, d))
    print("Clientes temporarios: %s (inativo, deve R$ 123,45) e %s (inativo, zerado)" % (REG_DIVIDA, REG_ZERADO))

    if USUARIO_REAL:
        # ── 1) login REAL da Inove: sessao por link magico gerado pelo admin (nao manda e-mail,
        #        nao troca a senha dela); a sessao e encerrada no fim ──
        st, lst = http("GET", "/auth/v1/admin/users?page=1&per_page=1000", SECRET)
        u = next((x for x in (lst or {}).get("users", []) if (x.get("email") or "").lower() == USUARIO_REAL), None)
        if not u:
            sys.exit("Nao achei o usuario %s em Authentication > Users (o convite ja foi enviado?)" % USUARIO_REAL)
        uid = u["id"]
        app = u.get("app_metadata") or {}
        checa("login real tem papel inove", app.get("papel") == "inove", str(app.get("papel")))
        checa("login real aponta para o dono certo", app.get("dono_id") == dono_id, str(app.get("dono_id")))
        if app.get("papel") != "inove":
            sys.exit("Usuario %s nao tem papel inove; parei antes de testar." % USUARIO_REAL)
        st, lk = http("POST", "/auth/v1/admin/generate_link", SECRET, corpo={"type": "magiclink", "email": USUARIO_REAL})
        th = (lk or {}).get("hashed_token") or ((lk or {}).get("properties") or {}).get("hashed_token")
        if st != 200 or not th:
            sys.exit("Nao gerei o link de acesso: %s %s" % (st, str(lk)[:200]))
        st, s = http("POST", "/auth/v1/verify", PUB, corpo={"type": "magiclink", "token_hash": th})
        if st != 200 or not (s or {}).get("access_token"):
            sys.exit("Nao entrei com o login real: %s %s" % (st, str(s)[:200]))
        tok = s["access_token"]
        print("Entrei com o login REAL:", USUARIO_REAL)
    else:
        # ── 1) usuario temporario ──
        st, u = http("POST", "/auth/v1/admin/users", SECRET, corpo={
            "email": email, "password": senha, "email_confirm": True,
            "app_metadata": {"papel": "inove", "dono_id": dono_id}})
        if st not in (200, 201):
            sys.exit("Nao criei o usuario temporario: %s %s" % (st, u))
        uid = u["id"]
        print("Usuario temporario criado:", email)
        st, s = http("POST", "/auth/v1/token?grant_type=password", PUB, corpo={"email": email, "password": senha})
        if st != 200:
            sys.exit("Login do usuario temporario falhou: %s %s" % (st, s))
        tok = s["access_token"]

    # ── 2) leitura de todas as tabelas ──
    print("\n[Leitura] tudo fora da lista permitida tem que voltar vazio")
    for t in tabelas:
        if t in PERMITIDAS:
            continue
        st, d = http("GET", "/rest/v1/%s?select=*&limit=1" % t, PUB, tok)
        vazio = (st == 200 and d == []) or st in (401, 403, 404)
        # tabela sem nenhuma linha nao prova nada: avisa
        _, tem = http("GET", "/rest/v1/%s?select=*&limit=1" % t, SECRET)
        obs = "" if not vazio else ("(tabela vazia no banco: teste fraco)" if tem == [] else "")
        checa("nao le " + t, vazio, obs if vazio else "%s: %s" % (st, str(d)[:120]))

    print("\n[Views] so os campos permitidos")
    st, cli = http("GET", "/rest/v1/inove_clientes_v?select=*", PUB, tok)
    checa("le inove_clientes_v", st == 200 and isinstance(cli, list) and len(cli) > 0, "%s, %s linhas" % (st, len(cli) if isinstance(cli, list) else cli))
    if isinstance(cli, list) and cli:
        checa("inove_clientes_v tem SO nome/telefone/saldo", set(cli[0]) == CAMPOS_CLIENTES_V, str(sorted(cli[0])))
    print("\n[Regra: ativo OU saldo diferente de zero]")
    por_reg = {c["reg"]: c for c in (cli or [])}
    d1 = por_reg.get(REG_DIVIDA)
    checa("inativo COM divida aparece na lista", d1 is not None)
    if d1:
        checa("  ...com saldo R$ 123,45 e marcado inativo", abs(float(d1["saldo"]) - 123.45) < 0.001 and d1["ativo"] is False, str(d1))
        checa("  ...com telefone pronto para WhatsApp", d1["tel_wa"] == "5521900000001", str(d1["tel_wa"]))
    checa("inativo ZERADO nao aparece na lista", REG_ZERADO not in por_reg)
    _, todos = http("GET", "/rest/v1/cadastro_clientes?select=reg,status", SECRET)
    inativos = {t["reg"] for t in todos if t["status"] == "inativo"}
    errados = [c["reg"] for c in (cli or []) if c["reg"] in inativos and abs(float(c["saldo"])) < 0.005 and abs(float(c["credito"])) < 0.005]
    checa("nenhum inativo zerado na lista (clientes reais)", not errados, str(errados[:10]))
    errados = [c["reg"] for c in (cli or []) if (c["reg"] in inativos) == c["ativo"]]
    checa("coluna 'ativo' bate com o cadastro", not errados, str(errados[:10]))
    st, lc = http("POST", "/rest/v1/rpc/inove_listar_clientes", PUB, tok, {})
    regs_lc = {r["reg"] for r in (lc or [])} if st == 200 else set()
    checa("Pagamentos (inove_listar_clientes) tem o inativo com divida", REG_DIVIDA in regs_lc, str(st))
    checa("Pagamentos (inove_listar_clientes) nao tem o inativo zerado", REG_ZERADO not in regs_lc)
    checa("Pagamentos e aba Clientes mostram os mesmos clientes", regs_lc == set(por_reg), "so em um lado: %s" % sorted(regs_lc ^ set(por_reg))[:10])

    st, cm = http("GET", "/rest/v1/inove_controle_mensal_v?select=*&limit=500", PUB, tok)
    checa("le inove_controle_mensal_v", st == 200 and isinstance(cm, list) and len(cm) > 0, str(st))
    if isinstance(cm, list) and cm:
        vaz = PROIBIDOS_EM_VIEW & set(cm[0])
        checa("controle mensal sem comissao/extrato_url", not vaz, ", ".join(sorted(vaz)))
        checa("PDF do extrato escondido (ajuste padrao)", all(r.get("extrato_path") is None for r in cm))
    st, cf = http("GET", "/rest/v1/inove_config_v?select=*", PUB, tok)
    checa("le inove_config_v (frase do WhatsApp)", st == 200 and isinstance(cf, list) and len(cf) == 1, str(cf)[:120])
    st, pa = http("GET", "/rest/v1/pagamento_aportes?select=id&limit=1", PUB, tok)
    checa("continua lendo pagamento_aportes", st == 200 and isinstance(pa, list) and len(pa) == 1, str(st))

    print("\n[Funcoes]")
    st, lc = http("POST", "/rest/v1/rpc/inove_listar_clientes", PUB, tok, {})
    checa("inove_listar_clientes sem endereco", st == 200 and all(not (r.get("end_str") or r.get("bairro") or r.get("cidade") or r.get("uf")) for r in lc), str(st))
    st, pp = http("POST", "/rest/v1/rpc/inove_pedidos_pendentes", PUB, tok, {"p_mes": 9, "p_ano": 2026})
    checa("pedidos pendentes sem valor", st == 200 and all(set(r) == {"cliente_reg", "qtd", "mais_antigo"} for r in pp), str(pp)[:120])
    st, dt = http("POST", "/rest/v1/rpc/ideali_desfazer_tel", PUB, tok, {"p_reg": cli[0]["reg"] if cli else 1})
    checa("nao desfaz telefone (so o dono)", st >= 400, str(st))

    print("\n[Escrita proibida]")
    alvo = cli[0]["reg"] if cli else 1
    st, d = http("PATCH", "/rest/v1/cadastro_clientes?reg=eq.%s" % alvo, PUB, tok, {"tel": "000"}, {"Prefer": "return=representation"})
    checa("nao altera cadastro_clientes", (st == 200 and d == []) or st >= 400, "%s %s" % (st, str(d)[:80]))
    st, d = http("POST", "/rest/v1/controle_mensal", PUB, tok, {"cliente_reg": alvo, "mes": 0, "ano": 2020, "recebido": True})
    checa("nao insere direto em controle_mensal", st >= 400, "%s %s" % (st, str(d)[:80]))
    # Pela view: tem que ser barrado pela PERMISSAO (42501), nao so pelo gatilho da 049 (052b).
    # Usa a linha do cliente temporario (jan/2099), nunca um cliente real.
    def negado_por_permissao(st, d): return st in (401, 403) and isinstance(d, dict) and d.get("code") == "42501"
    for nome, metodo, corpo in (("valor_pago", "PATCH", {"valor_pago": 1}),
                                ("recebido", "PATCH", {"recebido": True}),
                                ("apagar", "DELETE", None)):
        st, d = http(metodo, "/rest/v1/inove_controle_mensal_v?cliente_reg=eq.%s" % REG_DIVIDA, PUB, tok, corpo,
                     {"Prefer": "return=representation"})
        checa("view so leitura: nao %s pela view (permissao)" % nome, negado_por_permissao(st, d), "%s %s" % (st, str(d)[:90]))

    print("\n[Storage]")
    for b, deve in (("casos", False), ("extratos", False), ("comprovantes", True)):
        st, d = http("POST", "/storage/v1/object/list/" + b, PUB, tok, {"prefix": "", "limit": 5})
        tem = st == 200 and isinstance(d, list) and len(d) > 0
        checa(("le " if deve else "nao le ") + "bucket " + b, tem == deve, "%s, %s itens" % (st, len(d) if isinstance(d, list) else d))

    print("\n[WhatsApp]")
    com_tel = por_reg.get(REG_DIVIDA)  # o inativo com divida (temporario) tem telefone
    if com_tel and com_tel.get("tel_wa"):
        st, d = http("POST", "/rest/v1/rpc/inove_registrar_whatsapp", PUB, tok, {"p_reg": com_tel["reg"]})
        checa("registra clique no WhatsApp", st in (200, 204), "%s %s" % (st, d))
        # so o clique do cliente TEMPORARIO (nunca apaga clique real da Inove)
        filtro = "usuario_id=eq.%s&cliente_reg=eq.%s" % (uid, REG_DIVIDA)
        st, h = http("GET", "/rest/v1/inove_whatsapp_cliques?%s&select=id,cliente_reg,usuario_email" % filtro, SECRET)
        checa("clique gravado com quem/cliente/quando", st == 200 and len(h) == 1 and h[0]["cliente_reg"] == com_tel["reg"], str(h)[:120])
        http("DELETE", "/rest/v1/inove_whatsapp_cliques?" + filtro, SECRET)
    else:
        checa("registra clique no WhatsApp", False, "nenhum cliente ativo com telefone valido para testar")
    sem_tel = next((c for c in (cli or []) if not c.get("tel_wa")), None)
    if sem_tel:
        st, d = http("POST", "/rest/v1/rpc/inove_registrar_whatsapp", PUB, tok, {"p_reg": sem_tel["reg"]})
        checa("recusa clique de cliente sem telefone", st >= 400, str(st))
    st, d = http("POST", "/rest/v1/rpc/inove_registrar_whatsapp", PUB, tok, {"p_reg": REG_ZERADO})
    checa("recusa clique de inativo zerado (fora da lista)", st >= 400, str(st))
finally:
    limpar_clientes_teste()
    if USUARIO_REAL:
        # login real: NUNCA apaga o usuario; so encerra a sessao aberta pelo teste
        if tok:
            st, _ = http("POST", "/auth/v1/logout?scope=local", PUB, tok)
            print("\nSessao de teste do login real encerrada (%s). Usuario %s mantido." % (st, USUARIO_REAL))
    elif uid:
        st, _ = http("DELETE", "/auth/v1/admin/users/" + uid, SECRET)
        print("\nUsuario temporario apagado:" if st in (200, 204) else "\nATENCAO: nao consegui apagar o usuario %s (%s) - apague em Authentication > Users:" % (uid, st), email)

falhas = [r for r in resultados if not r[0]]
print("\nResultado: %d testes, %d falha(s)" % (len(resultados), len(falhas)))
sys.exit(1 if falhas else 0)
