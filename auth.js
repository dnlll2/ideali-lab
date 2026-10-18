/* ================================================================
   auth.js — Login das páginas internas (Supabase Auth, e-mail e senha)
   Ideali Laboratório

   Carregar logo depois do supabase-js e antes de qualquer outro script
   da página. Só a chave PÚBLICA (publishable) fica aqui; o que cada
   usuário pode ver/alterar é decidido pelas regras de acesso (RLS) no
   banco, não por este arquivo.

   Papéis (auth.users.app_metadata.papel):
     'dono'  → acesso completo
     'inove' → só as páginas em PAGINAS_INOVE (o banco também restringe)
   ================================================================ */

var SUPABASE_URL = 'https://alqhhgysvehtgkwsxeok.supabase.co';
var SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_oq7JWHoMvMqvjeaTDGHoqA_din8-sjJ';
var SB_AUTH_STORAGE_KEY = 'sb-alqhhgysvehtgkwsxeok-auth-token';
var PAGINAS_INOVE = ['pagamentos-inove.html'];

// Um único cliente por aba (evita vários GoTrueClient brigando pela sessão)
function idealiClient() {
  if (!window.__idealiSb) window.__idealiSb = supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
  return window.__idealiSb;
}

// Lê a sessão salva pelo supabase-js sem esperar rede (só pra decidir se mostra o login)
function idealiSessaoLocal() {
  try {
    var s = JSON.parse(localStorage.getItem(SB_AUTH_STORAGE_KEY) || 'null');
    if (!s || !s.refresh_token || !s.user) return null;
    return s;
  } catch (e) { return null; }
}

function idealiPapel() {
  var s = idealiSessaoLocal();
  return (s && s.user && s.user.app_metadata && s.user.app_metadata.papel) || '';
}

function idealiPaginaAtual() {
  var p = location.pathname.split('/').pop();
  return p || 'index.html';
}


async function idealiSair() {
  try { await idealiClient().auth.signOut(); } catch (e) {}
  location.reload();
}

(function idealiGate() {
  var sessao = idealiSessaoLocal();
  var pagina = idealiPaginaAtual();

  // ── Tela de login (usada sem sessão, ou pra pedir o código de duas etapas)
  var css =
    '#auth-overlay{position:fixed;inset:0;z-index:99999;background:#0f1117;display:flex;align-items:center;justify-content:center;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:16px}' +
    '#auth-overlay .box{background:#1a1d27;border:0.5px solid rgba(255,255,255,0.1);border-radius:16px;padding:32px 28px;width:min(360px,100%);text-align:center}' +
    '#auth-overlay input{width:100%;height:42px;background:#0f1117;border:0.5px solid rgba(255,255,255,0.15);border-radius:8px;padding:0 14px;font-size:15px;color:#e2e8f0;outline:none;font-family:inherit;margin-bottom:10px;box-sizing:border-box}' +
    '#auth-overlay button{width:100%;height:42px;background:#1d4ed8;border:none;border-radius:8px;color:#fff;font-size:14px;font-weight:600;cursor:pointer;font-family:inherit}' +
    '#auth-overlay button:disabled{opacity:.6;cursor:default}' +
    '#auth-overlay .lnk{background:none;height:auto;margin-top:14px;color:#94a3b8;font-weight:400;font-size:12.5px;text-decoration:underline}' +
    '#auth-overlay .err{font-size:12.5px;color:#f87171;margin-bottom:10px;min-height:16px}' +
    '#auth-overlay .ok{color:#4ade80}' +
    'body>*:not(#auth-overlay){display:none!important}';

  if (sessao) {
    // Inove só entra nas páginas dela
    if (idealiPapel() === 'inove' && PAGINAS_INOVE.indexOf(pagina) === -1) {
      location.replace(PAGINAS_INOVE[0]);
      return;
    }
    // Senha certa mas código de duas etapas ainda não confirmado → pede o código
    // (o banco exige o nível aal2 de quem tem a verificação ativada)
    idealiClient().auth.mfa.getAuthenticatorAssuranceLevel().then(function (a) {
      if (a.data && a.data.nextLevel === 'aal2' && a.data.currentLevel !== 'aal2') montar(telaCodigo);
    });
    // Sessão revogada/expirada no servidor → volta pro login
    idealiClient().auth.onAuthStateChange(function (ev, s) {
      if (ev === 'SIGNED_OUT' || (ev === 'INITIAL_SESSION' && !s)) {
        location.reload();
      }
    });
    return;
  }

  function el(html) { var d = document.createElement('div'); d.innerHTML = html; return d.firstChild; }

  function telaSenha(box) {
    box.innerHTML =
      '<p style="font-size:30px;margin:0 0 8px">🦷</p>' +
      '<p style="font-size:18px;font-weight:600;color:#f1f5f9;margin:0 0 4px">Ideali Laboratório</p>' +
      '<p style="font-size:13px;color:#64748b;margin:0 0 22px">Entre com seu e-mail e senha</p>' +
      '<form id="auth-form" autocomplete="on">' +
        '<input id="auth-email" type="email" placeholder="E-mail" autocomplete="username" required>' +
        '<input id="auth-senha" type="password" placeholder="Senha" autocomplete="current-password" required>' +
        '<p class="err" id="auth-err"></p>' +
        '<button id="auth-btn" type="submit">Entrar</button>' +
      '</form>' +
      '<button class="lnk" id="auth-esqueci" type="button">Esqueci minha senha</button>';
    var form = box.querySelector('#auth-form');
    var err = box.querySelector('#auth-err');
    var btn = box.querySelector('#auth-btn');
    box.querySelector('#auth-email').focus();

    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      err.className = 'err'; err.textContent = '';
      btn.disabled = true; btn.textContent = 'Entrando...';
      var r = await idealiClient().auth.signInWithPassword({
        email: box.querySelector('#auth-email').value.trim(),
        password: box.querySelector('#auth-senha').value
      });
      if (r.error) {
        btn.disabled = false; btn.textContent = 'Entrar';
        err.textContent = 'E-mail ou senha incorretos.';
        return;
      }
      // Verificação em duas etapas, se a conta tiver
      var aal = await idealiClient().auth.mfa.getAuthenticatorAssuranceLevel();
      if (aal.data && aal.data.nextLevel === 'aal2' && aal.data.currentLevel !== 'aal2') {
        telaCodigo(box);
        return;
      }
      depoisDoLogin();
    });

    box.querySelector('#auth-esqueci').addEventListener('click', async function () {
      var email = box.querySelector('#auth-email').value.trim();
      if (!email) { err.className = 'err'; err.textContent = 'Digite seu e-mail acima primeiro.'; return; }
      var r = await idealiClient().auth.resetPasswordForEmail(email, {
        redirectTo: location.origin + location.pathname.replace(/[^/]*$/, '') + 'conta.html'
      });
      err.className = r.error ? 'err' : 'err ok';
      err.textContent = r.error ? 'Não deu para enviar agora. Tente de novo.' : 'Se o e-mail estiver cadastrado, chega um link para criar a senha.';
    });
  }

  async function telaCodigo(box) {
    box.innerHTML =
      '<p style="font-size:30px;margin:0 0 8px">🔐</p>' +
      '<p style="font-size:17px;font-weight:600;color:#f1f5f9;margin:0 0 4px">Verificação em duas etapas</p>' +
      '<p style="font-size:13px;color:#64748b;margin:0 0 22px">Digite o código de 6 números do seu app autenticador</p>' +
      '<form id="auth-form"><input id="auth-cod" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="000000" style="text-align:center;letter-spacing:6px;font-size:20px">' +
      '<p class="err" id="auth-err"></p><button id="auth-btn" type="submit">Confirmar</button></form>' +
      '<button class="lnk" id="auth-voltar" type="button">Voltar</button>';
    box.querySelector('#auth-cod').focus();
    box.querySelector('#auth-voltar').addEventListener('click', function () { idealiSair(); });
    box.querySelector('#auth-form').addEventListener('submit', async function (e) {
      e.preventDefault();
      var err = box.querySelector('#auth-err'), btn = box.querySelector('#auth-btn');
      btn.disabled = true;
      var fs = await idealiClient().auth.mfa.listFactors();
      var totp = fs.data && fs.data.totp && fs.data.totp[0];
      if (!totp) { depoisDoLogin(); return; }
      var r = await idealiClient().auth.mfa.challengeAndVerify({ factorId: totp.id, code: box.querySelector('#auth-cod').value.trim() });
      if (r.error) { btn.disabled = false; err.textContent = 'Código inválido. Tente de novo.'; return; }
      depoisDoLogin();
    });
  }

  function depoisDoLogin() {
    // Recarrega a página já com a sessão (o gate aplica o papel)
    location.reload();
  }

  function montar(tela) {
    function go() {
      if (document.getElementById('auth-overlay')) return;
      var st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
      var ov = el('<div id="auth-overlay"><div class="box"></div></div>');
      document.body.appendChild(ov);
      (tela || telaSenha)(ov.firstChild);
    }
    if (document.body) go(); else document.addEventListener('DOMContentLoaded', go);
  }
  // ── Sem sessão: tela de login ──
  montar(telaSenha);

  // Impede o resto da página de rodar consultas sem sessão
  window.IDEALI_SEM_SESSAO = true;
})();

// ── Links de arquivos (buckets privados) ──────────────────────
// O banco guarda o endereço "público" antigo (…/object/public/<bucket>/<caminho>).
// Os buckets agora são privados: troca, só na memória, por link assinado (1 hora).
async function idealiAssinarUrls(rows, campo, bucket) {
  if (!rows || !rows.length) return rows;
  var marca = '/object/public/' + bucket + '/';
  var alvo = [];
  rows.forEach(function (r) {
    var u = r && r[campo];
    if (typeof u === 'string' && u.indexOf(marca) >= 0) {
      alvo.push({ r: r, path: decodeURIComponent(u.split(marca)[1].split('?')[0]) });
    }
  });
  if (!alvo.length) return rows;
  var res = await idealiClient().storage.from(bucket).createSignedUrls(alvo.map(function (a) { return a.path; }), 3600);
  (res.data || []).forEach(function (s, i) { if (s && s.signedUrl) alvo[i].r[campo] = s.signedUrl; });
  return rows;
}

// Qualquer link para arquivo "público" antigo (comprovantes/extratos/casos) vira
// link assinado na hora do clique — cobre todas as telas sem mexer em cada uma.
document.addEventListener('click', function (ev) {
  var a = ev.target && ev.target.closest && ev.target.closest('a[href*="/storage/v1/object/public/"]');
  if (!a) return;
  var m = a.href.match(/\/storage\/v1\/object\/public\/([^/]+)\/([^?#]+)/);
  if (!m) return;
  ev.preventDefault();
  var novaAba = a.target === '_blank' || ev.ctrlKey || ev.metaKey;
  var w = novaAba ? window.open('', '_blank') : null;   // abre já (evita bloqueio de pop-up)
  idealiClient().storage.from(m[1]).createSignedUrl(decodeURIComponent(m[2]), 3600).then(function (r) {
    var url = r.data && r.data.signedUrl;
    if (!url) { if (w) w.close(); alert('Não deu para abrir o arquivo. Entre de novo e tente outra vez.'); return; }
    if (w) w.location.href = url; else location.href = url;
  });
}, true);
