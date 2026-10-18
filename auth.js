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

// "Lembrar meu e-mail": guarda SÓ o e-mail neste aparelho (nunca a senha)
var EMAIL_LEMBRADO_KEY = 'ideali-email-lembrado';
function idealiEmailLembrado() {
  try { return localStorage.getItem(EMAIL_LEMBRADO_KEY) || ''; } catch (e) { return ''; }
}
function idealiLembrarEmail(email) {
  try {
    if (email) localStorage.setItem(EMAIL_LEMBRADO_KEY, email);
    else localStorage.removeItem(EMAIL_LEMBRADO_KEY);
  } catch (e) {}
}

function idealiPaginaAtual() {
  var p = location.pathname.split('/').pop();
  return p || 'index.html';
}

// ── App 2.0: as telas antigas abrem dentro do index.html (menu novo) ──
// Página antiga aberta direto no navegador → vai para a rota dela no app.
var IDEALI_PAGINA_ROTA = {
  'home.html': 'mais/painel', 'pedidos.html': 'producao/pedidos', 'ordens-cam.html': 'producao/cam',
  'cadastro.html': 'clientes/cadastro', 'convites.html': 'clientes/portal',
  'contas-receber.html': 'financeiro/receber', 'pagamentos-inove.html': 'inove/pagamentos',
  'cobranca.html': 'financeiro/cobranca', 'recibo.html': 'financeiro/recibos', 'gastos.html': 'financeiro/gastos',
  'relatorio.html': 'financeiro/relatorio', 'tarefas.html': 'mais/tarefas', 'orcamento.html': 'mais/orcamento',
  'relatorios.html': 'mais/relatorios', 'dashboard.html': 'mais/dashboard', 'resumo.html': 'mais/resumo',
  'inove-3d.html': 'inove/3d', 'inove.html': 'inove/controle', 'tabela-precos.html': 'config/precos'
};
// Dentro do app (iframe): esconde o menu lateral antigo
var IDEALI_EMBUTIDO = (function () { try { return window.self !== window.top; } catch (e) { return true; } })();
if (IDEALI_EMBUTIDO) {
  document.documentElement.classList.add('ideali-embutido');
  var _st = document.createElement('style');
  _st.textContent = '.ideali-embutido #sidebar,.ideali-embutido #sidebar-overlay,' +
    '.ideali-embutido button[onclick="openSidebar()"]{display:none!important}';
  document.head.appendChild(_st);
}


async function idealiSair() {
  try { await idealiClient().auth.signOut(); } catch (e) {}
  location.reload();
}

(function idealiGate() {
  var sessao = idealiSessaoLocal();
  var pagina = idealiPaginaAtual();

  // ── Tela de login (usada sem sessão, ou pra pedir o código de duas etapas)
  // Mesmo visual do app 2.0 (Ideali Lab): foto de fundo escolhida neste aparelho + caixa de vidro
  var FUNDO = 'url("assets/fundos/praia.jpg"), url("assets/fundos/praia-mini.jpg")', FUNDO_COR = '#918a7a';
  try { FUNDO = localStorage.getItem('ideali-fundo-css') || FUNDO; FUNDO_COR = localStorage.getItem('ideali-fundo-cor') || FUNDO_COR; } catch (e) {}
  var CLARO = '--a-sf:rgba(255,255,255,.80);--a-ink:#0F2226;--a-mu:#4A6064;--a-ln:rgba(15,34,38,.16);--a-ac:#0B7A80;--a-aci:#FFFFFF;--a-er:#C2362E;--a-ok:#1E7F55;--a-film:rgba(6,18,22,.30);--a-in:rgba(255,255,255,.92);';
  var ESCURO = '--a-sf:rgba(12,22,26,.72);--a-ink:#E7F2F3;--a-mu:#A3B8BB;--a-ln:rgba(255,255,255,.14);--a-ac:#4FD1C5;--a-aci:#06201F;--a-er:#FF7A70;--a-ok:#5BD69B;--a-film:rgba(2,8,12,.55);--a-in:rgba(8,16,20,.55);';
  var css =
    '#auth-overlay{' + CLARO + '}' +
    '@media (prefers-color-scheme: dark){:root:not([data-theme="light"]) #auth-overlay{' + ESCURO + '}}' +
    ':root[data-theme="dark"] #auth-overlay{' + ESCURO + '}' +
    '#auth-overlay{position:fixed;inset:0;z-index:99999;background-color:' + FUNDO_COR + ';background-image:' + FUNDO.replace(/"/g, "'") + ';background-size:cover;background-position:center;' +
      'color:var(--a-ink);display:flex;align-items:center;justify-content:center;' +
      'font-family:"Manrope",system-ui,-apple-system,"Segoe UI",sans-serif;padding:16px;box-sizing:border-box}' +
    '#auth-overlay::before{content:"";position:absolute;inset:0;background:var(--a-film)}' +
    '#auth-overlay *{box-sizing:border-box}' +
    '#auth-overlay .box{position:relative;overflow:hidden;background:var(--a-sf);border:1px solid rgba(255,255,255,.35);border-radius:22px;padding:34px 28px 26px;width:min(380px,100%);text-align:center;' +
      '-webkit-backdrop-filter:blur(18px) saturate(140%);backdrop-filter:blur(18px) saturate(140%);box-shadow:0 24px 60px -24px rgba(0,0,0,.55)}' +
    '#auth-overlay .logo{width:54px;height:54px;border-radius:50%;background:linear-gradient(140deg,#0B7A80,#3CC2B3);color:#fff;display:grid;place-items:center;margin:0 auto 12px;' +
      'box-shadow:0 6px 16px -6px rgba(0,0,0,.45),inset 0 0 0 1px rgba(255,255,255,.35)}' +
    '#auth-overlay .logo svg{width:28px;height:28px}' +
    '#auth-overlay h1{font-family:"Manrope",system-ui,sans-serif;font-size:22px;font-weight:800;letter-spacing:-.02em;margin:0 0 4px;color:var(--a-ink)}' +
    '#auth-overlay .sub{font-size:14px;color:var(--a-mu);margin:0 0 22px}' +
    '#auth-overlay input{width:100%;height:46px;background:var(--a-in);border:1.5px solid var(--a-ln);border-radius:12px;padding:0 14px;font-size:16px;color:var(--a-ink);outline:none;font-family:inherit;margin:0 0 10px}' +
    '#auth-overlay input:focus{border-color:var(--a-ac);box-shadow:0 0 0 3px color-mix(in srgb,var(--a-ac) 22%,transparent)}' +
    '#auth-overlay button{width:100%;height:46px;background:var(--a-ac);border:none;border-radius:999px;color:var(--a-aci);font-size:15px;font-weight:700;cursor:pointer;font-family:inherit}' +
    '#auth-overlay button:disabled{opacity:.6;cursor:default}' +
    '#auth-overlay .lnk{background:none;height:auto;margin-top:14px;color:var(--a-mu);font-weight:500;font-size:13px;text-decoration:underline}' +
    '#auth-overlay .err{font-size:13px;color:var(--a-er);margin:0 0 10px;min-height:17px}' +
    '#auth-overlay .ok{color:var(--a-ok)}' +
    '#auth-overlay .lembrar{display:flex;align-items:center;gap:9px;text-align:left;font-size:14px;color:var(--a-ink);margin:4px 0 12px;cursor:pointer;user-select:none}' +
    '#auth-overlay .lembrar input{width:19px;height:19px;margin:0;padding:0;flex-shrink:0;accent-color:var(--a-ac);cursor:pointer}' +
    'body>*:not(#auth-overlay){display:none!important}';
  var LOGO = '<div class="logo"><svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M7.4 2.6c1.6 0 2.7.8 4.6.8s3-.8 4.6-.8C19.5 2.6 21 5 21 8c0 2.2-.8 3.7-1.4 5.5-.6 1.9-.8 4.2-1.3 6.2-.4 1.6-1 2.4-1.9 2.4-1.2 0-1.5-1.4-1.9-3.4-.3-1.6-.7-3.2-2.5-3.2s-2.2 1.6-2.5 3.2c-.4 2-.7 3.4-1.9 3.4-.9 0-1.5-.8-1.9-2.4-.5-2-.7-4.3-1.3-6.2C3.8 11.7 3 10.2 3 8c0-3 1.5-5.4 4.4-5.4z"/></svg></div>';

  if (sessao) {
    // Inove só entra nas páginas dela
    if (idealiPapel() === 'inove' && PAGINAS_INOVE.indexOf(pagina) === -1) {
      location.replace(PAGINAS_INOVE[0]);
      return;
    }
    // Dono abrindo uma tela antiga direto → abre dentro do app novo, na rota certa (F5 continua nela)
    if (idealiPapel() !== 'inove' && !IDEALI_EMBUTIDO && IDEALI_PAGINA_ROTA[pagina]) {
      location.replace('index.html#/' + IDEALI_PAGINA_ROTA[pagina]);
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
      LOGO +
      '<h1>Ideali Lab</h1>' +
      '<p class="sub">Entre com seu e-mail e senha</p>' +
      '<form id="auth-form" autocomplete="on">' +
        '<input id="auth-email" name="email" type="email" placeholder="E-mail" autocomplete="username" required>' +
        '<input id="auth-senha" name="password" type="password" placeholder="Senha" autocomplete="current-password" required>' +
        '<label class="lembrar"><input id="auth-lembrar" type="checkbox" checked> Lembrar meu e-mail e senha neste aparelho</label>' +
        '<p class="err" id="auth-err"></p>' +
        '<button id="auth-btn" type="submit">Entrar</button>' +
      '</form>' +
      '<button class="lnk" id="auth-esqueci" type="button">Esqueci minha senha</button>';
    var form = box.querySelector('#auth-form');
    var err = box.querySelector('#auth-err');
    var btn = box.querySelector('#auth-btn');
    var campoEmail = box.querySelector('#auth-email');
    var campoSenha = box.querySelector('#auth-senha');
    var lembrar = box.querySelector('#auth-lembrar');

    // Só o e-mail fica guardado no aparelho; a senha quem guarda é o gerenciador de senhas do navegador
    var emailSalvo = idealiEmailLembrado();
    if (emailSalvo) { campoEmail.value = emailSalvo; campoSenha.focus(); }
    else campoEmail.focus();

    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      err.className = 'err'; err.textContent = '';
      btn.disabled = true; btn.textContent = 'Entrando...';
      var email = campoEmail.value.trim(), senha = campoSenha.value;
      var r = await idealiClient().auth.signInWithPassword({ email: email, password: senha });
      if (r.error) {
        btn.disabled = false; btn.textContent = 'Entrar';
        err.textContent = 'E-mail ou senha incorretos.';
        return;
      }
      if (lembrar.checked) {
        idealiLembrarEmail(email);
        // Pede ao navegador para oferecer "Salvar senha?" (Chrome/Edge/Android; nos outros o próprio formulário já basta)
        if (window.PasswordCredential && navigator.credentials && navigator.credentials.store) {
          try { await navigator.credentials.store(new PasswordCredential({ id: email, password: senha })); } catch (x) {}
        }
      } else {
        idealiLembrarEmail(null);
      }
      senha = null; campoSenha.value = '';
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
      LOGO +
      '<h1>Verificação em duas etapas</h1>' +
      '<p class="sub">Digite o código de 6 números do seu app autenticador</p>' +
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
      if (!document.querySelector('link[href*="Manrope"]')) {
        var fl = document.createElement('link'); fl.rel = 'stylesheet';
        fl.href = 'https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&display=swap';
        document.head.appendChild(fl);
      }
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
