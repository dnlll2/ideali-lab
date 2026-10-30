# Convite por e-mail para o login da Inove (papel inove).
#
#   python testes/convidar_inove.py            -> SO MOSTRA o que vai fazer (nao envia nada)
#   python testes/convidar_inove.py --enviar   -> envia o convite de verdade
#
# O que faz com --enviar:
#   1. confere que ainda nao existe usuario com esse e-mail (se existir, para)
#   2. envia o convite do Supabase (e-mail com link para definir a senha em conta.html)
#   3. grava papel = inove e dono_id = dono no app_metadata (so o admin altera isso)
#   4. confere o que ficou gravado
# Depois que ela definir a senha:
#   python testes/teste_negacao_inove_052.py --usuario-real inove3dlab@gmail.com
# Precisa de SUPABASE_SECRET_KEY no .env (raiz do repo).
import json, os, sys, urllib.request, urllib.error

EMAIL = "inove3dlab@gmail.com"
URL = "https://alqhhgysvehtgkwsxeok.supabase.co"
DESTINO = "https://dnlll2.github.io/ideali-lab/conta.html"   # pagina que pede a senha nova (type=invite)
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SECRET = next((l.split("=", 1)[1].strip() for l in open(os.path.join(RAIZ, ".env"), encoding="utf-8")
               if l.startswith("SUPABASE_SECRET_KEY=")), None) or sys.exit("Falta SUPABASE_SECRET_KEY no .env")
ENVIAR = "--enviar" in sys.argv

def http(metodo, caminho, corpo=None):
    req = urllib.request.Request(URL + caminho, method=metodo,
                                 headers={"apikey": SECRET, "Authorization": "Bearer " + SECRET, "Content-Type": "application/json"},
                                 data=json.dumps(corpo).encode("utf-8") if corpo is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            t = r.read().decode("utf-8"); return r.status, (json.loads(t) if t else None)
    except urllib.error.HTTPError as e:
        t = e.read().decode("utf-8", "replace")
        try: return e.code, json.loads(t)
        except Exception: return e.code, t

st, cfg = http("GET", "/rest/v1/ideali_config?select=dono_id")
dono_id = cfg[0]["dono_id"] if st == 200 and cfg else sys.exit("Nao achei ideali_config.dono_id: %s %s" % (st, cfg))
st, lst = http("GET", "/auth/v1/admin/users?page=1&per_page=1000")
existe = next((u for u in (lst or {}).get("users", []) if (u.get("email") or "").lower() == EMAIL), None)

print("E-mail:   ", EMAIL)
print("Papel:     inove   | dono_id:", dono_id)
print("Link leva: ", DESTINO)
if existe:
    sys.exit("Ja existe usuario com esse e-mail (id %s, papel %s). Nada enviado."
             % (existe["id"], (existe.get("app_metadata") or {}).get("papel")))
if not ENVIAR:
    sys.exit("\nSimulacao: nada foi enviado. Para enviar de verdade: python testes/convidar_inove.py --enviar")

st, u = http("POST", "/auth/v1/invite?redirect_to=" + urllib.request.quote(DESTINO, safe=""), {"email": EMAIL})
if st not in (200, 201) or not (u or {}).get("id"):
    sys.exit("Convite NAO enviado: %s %s" % (st, str(u)[:300]))
uid = u["id"]
print("Convite enviado. Usuario criado:", uid)
st, u2 = http("PUT", "/auth/v1/admin/users/" + uid, {"app_metadata": {"papel": "inove", "dono_id": dono_id}})
app = (u2 or {}).get("app_metadata") or {}
if st != 200 or app.get("papel") != "inove" or app.get("dono_id") != dono_id:
    sys.exit("ATENCAO: convite enviado, mas o papel NAO foi gravado (%s %s). Sem papel ela nao ve nada; rode de novo ou ajuste em Authentication > Users." % (st, app))
print("Papel gravado:", app)
print("\nPronto. Quando ela definir a senha, rode:\n  python testes/teste_negacao_inove_052.py --usuario-real " + EMAIL)
