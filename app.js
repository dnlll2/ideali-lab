/* ================================================================
   app.js — Casca do Ideali Lab 2.0 ("navegador calmo")
   Abas como num navegador, busca em tudo, Início com relógio e atalhos,
   fundos de paisagem (Configurações › Aparência).

   As telas que ainda não foram refeitas abrem dentro do app (iframe) no
   modo "embutido": sem o menu lateral antigo, seguindo o tema claro/escuro.
   Cada aba guarda a própria tela aberta, então trocar de aba não recarrega.
   ================================================================ */
var sb = idealiClient();

// ── Menu ──────────────────────────────────────────────────────
var SECOES = {
  inicio:     { nome: 'Início',     icon: 'ti-home' },
  producao:   { nome: 'Produção',   icon: 'ti-layout-kanban', abas: [
                ['pedidos', 'Pedidos', 'pedidos.html'],
                ['cam', 'Ordens CAM', 'ordens-cam.html']] },
  clientes:   { nome: 'Clientes',   icon: 'ti-users', abas: [
                ['cadastro', 'Dentistas e clínicas', 'cadastro.html'],
                ['portal', 'Portal e convites', 'convites.html']] },
  financeiro: { nome: 'Financeiro', icon: 'ti-wallet', abas: [
                ['receber', 'A receber', 'contas-receber.html'],
                ['inove', 'Pagamentos Inove', 'pagamentos-inove.html'],
                ['cobranca', 'Cobrança e Pix', 'cobranca.html'],
                ['recibos', 'Recibos', 'recibo.html'],
                ['gastos', 'Gastos de entrega', 'gastos.html'],
                ['relatorio', 'Relatório do mês', 'relatorio.html']] },
  mais:       { nome: 'Mais',       icon: 'ti-dots' }
};
// Telas que abrem a partir do "Mais" e das Configurações (viram abas extras)
var SUBPAGINAS = {
  mais: {
    tarefas:    ['Tarefas', 'tarefas.html', 'ti-checklist'],
    orcamento:  ['Orçamentos', 'orcamento.html', 'ti-file-dollar'],
    relatorios: ['Relatórios', 'relatorios.html', 'ti-report'],
    painel:     ['Painel completo', 'home.html', 'ti-chart-bar'],
    dashboard:  ['Dashboard', 'dashboard.html', 'ti-chart-pie'],
    resumo:     ['Resumo', 'resumo.html', 'ti-list-details'],
    'inove-3d': ['Inove 3D', 'inove-3d.html', 'ti-cube'],
    inove:      ['Inove: controle mensal', 'inove.html', 'ti-calendar-stats']
  },
  config: {
    precos: ['Tabela de preços', 'tabela-precos.html', 'ti-currency-real'],
    conta:  ['Minha conta', 'conta.html', 'ti-lock']
  }
};
// Registros abertos pela busca: cada um vira uma aba ("Dr. Fulano", "Pedido #142")
var REGISTROS = {
  cliente: { pagina: 'cadastro.html',   icon: 'ti-user',      titulo: function (id) { return 'Cliente #' + id; } },
  pedido:  { pagina: 'pedidos.html',    icon: 'ti-file-text', titulo: function (id) { return 'Pedido #' + id; } },
  cam:     { pagina: 'ordens-cam.html', icon: 'ti-cube',      titulo: function (id) { return 'CAM #' + id; } }
};

var $ = function (id) { return document.getElementById(id); };
function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
function brl(v) { return 'R$ ' + Number(v || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
function brlCurto(v) {
  v = Number(v || 0);
  if (Math.abs(v) >= 10000) return 'R$ ' + (v / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 1 }) + ' mil';
  return brl(v);
}
var MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
var MESES_CURTOS = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];   // mes do banco é 0-indexado
var DIAS = ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'];
function isoLocal(d) { return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }
function somaDias(d, n) { var x = new Date(d); x.setDate(x.getDate() + n); return x; }
function diasEntre(aIso, bIso) { return Math.round((new Date(bIso + 'T12:00:00') - new Date(aIso + 'T12:00:00')) / 86400000); }
function lerLocal(k, padrao) { try { var v = localStorage.getItem(k); return v == null ? padrao : JSON.parse(v); } catch (e) { return padrao; } }
function gravarLocal(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }
function cada(sel, fn) { Array.prototype.forEach.call(document.querySelectorAll(sel), fn); }

// ── Aparência (claro / escuro / automático) ───────────────────
function aparencia() { try { return localStorage.getItem('ideali-aparencia') || 'auto'; } catch (e) { return 'auto'; } }
function escuroAgora() {
  var a = aparencia();
  return a === 'escuro' || (a === 'auto' && window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches);
}
function aplicarAparencia(a) {
  try { localStorage.setItem('ideali-aparencia', a); } catch (e) {}
  if (a === 'claro') document.documentElement.dataset.theme = 'light';
  else if (a === 'escuro') document.documentElement.dataset.theme = 'dark';
  else delete document.documentElement.dataset.theme;
  sincronizarTemaAntigo(true);
  atualizarBotoesMenu();
}
// As telas antigas usam o tema "Ideali" (vidro do Lab): claro ou escuro conforme o app
function sincronizarTemaAntigo(aplicar) {
  var alvo = escuroAgora() ? 'ideali-escuro' : 'ideali';
  try { localStorage.setItem('ideali-theme', alvo); } catch (e) {}
  if (!aplicar) return;
  cada('#janela iframe', function (f) {
    try { if (f.contentWindow.applyTheme) f.contentWindow.applyTheme(alvo); else f.contentWindow.location.reload(); } catch (e) {}
  });
}
if (window.matchMedia) matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () {
  if (aparencia() === 'auto') { sincronizarTemaAntigo(true); atualizarBotoesMenu(); }
});

// ── Fundos (foto de paisagem, degradê ou cor) ─────────────────
// Fotos do Pexels (licença livre), baixadas para assets/fundos. Créditos em assets/fundos/creditos.json.
var FUNDOS = [
  { id: 'praia',      tipo: 'foto', nome: 'Praia ao entardecer', autor: 'Griffin Wooldridge',      cor: '#918a7a' },
  { id: 'montanha',   tipo: 'foto', nome: 'Montanha',            autor: 'eberhard grossgasteiger', cor: '#9ba19f' },
  { id: 'entardecer', tipo: 'foto', nome: 'Lago ao pôr do sol',  autor: 'Ahmet Yüksek',            cor: '#746d65' },
  { id: 'lago',       tipo: 'foto', nome: 'Lago com neblina',    autor: 'Courtney RA',             cor: '#9d7561' },
  { id: 'rosa',       tipo: 'foto', nome: 'Montanhas rosadas',   autor: 'Ray Bilcliff',            cor: '#ab8a86' },
  { id: 'floresta',   tipo: 'foto', nome: 'Floresta',            autor: 'Melih Özmen',             cor: '#40511f' },
  { id: 'ceu',        tipo: 'foto', nome: 'Céu sobre a floresta', autor: 'Matthias Groeneveld',    cor: '#958770' },
  { id: 'agua',       tipo: 'degrade', nome: 'Verde-água', cor: '#1f6f73',
    css: 'radial-gradient(ellipse 90% 70% at 15% 10%,#5fc9b8 0%,transparent 60%),radial-gradient(ellipse 80% 80% at 90% 90%,#1b4e6b 0%,transparent 60%),linear-gradient(160deg,#2a8f8a,#164a5a)' },
  { id: 'tarde',      tipo: 'degrade', nome: 'Fim de tarde', cor: '#7a5a7e',
    css: 'radial-gradient(ellipse 90% 70% at 85% 15%,#f2a07b 0%,transparent 55%),radial-gradient(ellipse 80% 80% at 10% 90%,#3b4a7a 0%,transparent 60%),linear-gradient(170deg,#8a6a9a,#2f3d63)' },
  { id: 'noite',      tipo: 'degrade', nome: 'Noite calma', cor: '#18303a',
    css: 'radial-gradient(ellipse 70% 60% at 20% 20%,#2f6f7a 0%,transparent 60%),radial-gradient(ellipse 70% 70% at 85% 80%,#3a3566 0%,transparent 60%),linear-gradient(180deg,#0f2a33,#0b1620)' },
  { id: 'grafite',    tipo: 'solida', nome: 'Grafite', cor: '#2b3a3f', css: 'none' },
  { id: 'minha',      tipo: 'minha', nome: 'Minha foto', cor: '#40585c' }
];
function fundoPorId(id) { return FUNDOS.filter(function (f) { return f.id === id; })[0]; }
function fundoAtual() { try { return localStorage.getItem('ideali-fundo') || 'praia'; } catch (e) { return 'praia'; } }
var MINHA_FOTO = null;   // dataURL da foto do usuário (também guardada no aparelho)
function aplicarFundo(id) {
  var f = fundoPorId(id) || fundoPorId('praia');
  var css;
  if (f.tipo === 'foto') css = 'url("assets/fundos/' + f.id + '.jpg"), url("assets/fundos/' + f.id + '-mini.jpg")';
  else if (f.tipo === 'minha') {
    var m = MINHA_FOTO || (lerLocal('ideali-fundo-minha', null) || {}).url;
    if (!m) { f = fundoPorId('praia'); return aplicarFundo('praia'); }
    css = 'url("' + m + '")';
  } else css = f.css;
  var s = document.documentElement.style;
  s.setProperty('--fundo', css);
  s.setProperty('--fundo-cor', f.cor);
  try {
    localStorage.setItem('ideali-fundo', f.id);
    localStorage.setItem('ideali-fundo-css', f.tipo === 'minha' ? css : css);
    localStorage.setItem('ideali-fundo-cor', f.cor);
  } catch (e) {
    // A foto do usuário pode não caber no armazenamento do aparelho: guarda só o nome
    try { localStorage.setItem('ideali-fundo', f.id); localStorage.removeItem('ideali-fundo-css'); } catch (e2) {}
  }
}

// ── Usuário e preferências (ficam no próprio login, user_metadata) ──
var USUARIO = null;
function meta() { return (USUARIO && USUARIO.user_metadata) || {}; }
async function carregarUsuario() {
  var r = await sb.auth.getUser();
  USUARIO = r.data && r.data.user;
  var nome = meta().nome || '';
  $('av').textContent = (nome || (USUARIO && USUARIO.email) || '?').trim().charAt(0).toUpperCase();
  $('av-nome').textContent = nome || 'Minha conta';
  $('av-email').textContent = (USUARIO && USUARIO.email) || '';
}
var _prefsPendentes = {}, _prefsTimer = null;
function salvarPrefs(dados) {
  Object.keys(dados).forEach(function (k) { _prefsPendentes[k] = dados[k]; });
  clearTimeout(_prefsTimer);
  _prefsTimer = setTimeout(async function () {
    var d = _prefsPendentes; _prefsPendentes = {};
    var r = await sb.auth.updateUser({ data: d });
    if (!r.error && r.data && r.data.user) USUARIO = r.data.user;
  }, 600);
}
// Outro aparelho escolheu outro fundo/atalhos: segue o que está na conta
async function sincronizarPrefs() {
  var m = meta();
  if (m.atalhos) gravarLocal('ideali-atalhos', m.atalhos);
  if (!m.fundo) return;
  if (m.fundo === 'minha') {
    var cache = lerLocal('ideali-fundo-minha', null);
    if (cache && cache.v === m.fundo_minha_v) { MINHA_FOTO = cache.url; }
    else {
      var r = await sb.storage.from('fundos').download(USUARIO.id + '/fundo.jpg');
      if (r.error || !r.data) return;
      MINHA_FOTO = await blobParaDataUrl(r.data);
      gravarLocal('ideali-fundo-minha', { v: m.fundo_minha_v, url: MINHA_FOTO });
    }
  }
  if (m.fundo !== fundoAtual() || m.fundo === 'minha') aplicarFundo(m.fundo);
}

// ── Rotas: #/secao/sub[/extra] ────────────────────────────────
function rotaAtual() {
  var p = (location.hash || '').replace(/^#\/?/, '').split('/').filter(Boolean).map(decodeURIComponent);
  var sec = p[0] || 'inicio';
  if (!SECOES[sec] && sec !== 'config' && !REGISTROS[sec]) sec = 'inicio';
  if (REGISTROS[sec] && !p[1]) sec = 'inicio';
  return { sec: sec, sub: p[1] || null, extra: p[2] || null };
}
function chaveRota(r) { return r.sec + (r.sub ? '/' + r.sub : ''); }
function rotaEhExtra(r) {
  if (REGISTROS[r.sec]) return true;
  if (r.sec === 'config') return !r.sub || !!SUBPAGINAS.config[r.sub];
  return r.sec === 'mais' && !!r.sub && !!SUBPAGINAS.mais[r.sub];
}

// Chamado pelas telas antigas quando elas navegam (sbNav) estando dentro do app
window.idealiAbrirPagina = function (pagina) {
  var r = (window.IDEALI_PAGINA_ROTA || {})[pagina];
  if (r) location.hash = '#/' + r;
};

// ── Abas (fixas + extras com X, lembradas no aparelho) ────────
var EXTRAS = lerLocal('ideali-abas', []);
if (!Array.isArray(EXTRAS)) EXTRAS = [];
function infoExtra(r) {
  if (REGISTROS[r.sec]) return { icon: REGISTROS[r.sec].icon, titulo: REGISTROS[r.sec].titulo(r.sub) };
  if (r.sec === 'config' && !r.sub) return { icon: 'ti-settings', titulo: 'Configurações' };
  var s = SUBPAGINAS[r.sec][r.sub];
  return { icon: s[2], titulo: s[0] };
}
// Abre um registro numa aba já com o nome certo (ex.: "Dr. Fulano")
function abrirAba(rota, titulo) {
  var e = EXTRAS.filter(function (x) { return x.rota === rota; })[0];
  if (e) e.titulo = titulo || e.titulo;
  else if (titulo) EXTRAS.push({ rota: rota, titulo: titulo });
  gravarLocal('ideali-abas', EXTRAS);
  if (location.hash === '#/' + rota) render(); else location.hash = '#/' + rota;
}
function garantirExtra(r) {
  var k = chaveRota(r);
  if (EXTRAS.some(function (x) { return x.rota === k; })) return;
  var i = infoExtra(r);
  EXTRAS.push({ rota: k, titulo: i.titulo });
  gravarLocal('ideali-abas', EXTRAS);
  if (r.sec === 'cliente') nomeDoCliente(r.sub);
}
async function nomeDoCliente(reg) {
  var r = await sb.from('cadastro_clientes').select('nome').eq('reg', reg).maybeSingle();
  if (r.data && r.data.nome) {
    EXTRAS.forEach(function (x) { if (x.rota === 'cliente/' + reg) x.titulo = r.data.nome; });
    gravarLocal('ideali-abas', EXTRAS);
    renderAbas(rotaAtual());
  }
}
function fecharAba(k) {
  var i = EXTRAS.findIndex(function (x) { return x.rota === k; });
  if (i < 0) return;
  EXTRAS.splice(i, 1);
  gravarLocal('ideali-abas', EXTRAS);
  var p = (function () { var a = k.split('/'); return paginaDaRota({ sec: a[0], sub: a[1] || null }); })();
  if (p) removerFrame(p);
  if (chaveRota(rotaAtual()) === k) {
    var prox = EXTRAS[Math.min(i, EXTRAS.length - 1)];
    location.hash = '#/' + (prox ? prox.rota : 'inicio');
  } else renderAbas(rotaAtual());
}

function renderAbas(r) {
  var k = chaveRota(r);
  var html = ['inicio', 'producao', 'clientes', 'financeiro'].map(function (s) {
    return '<a class="aba' + (r.sec === s ? ' on' : '') + '" href="#/' + s + '"' + (r.sec === s ? ' aria-current="page"' : '') + '>' +
      '<i class="ti ' + SECOES[s].icon + '"></i><span>' + SECOES[s].nome + '</span></a>';
  }).join('') +
    '<a class="aba so-icone' + (r.sec === 'mais' && !r.sub ? ' on' : '') + '" href="#/mais" title="Mais" aria-label="Mais"><i class="ti ti-dots"></i></a>';
  if (EXTRAS.length) {
    html += '<span class="sep-abas" aria-hidden="true"></span>' + EXTRAS.map(function (e) {
      var a = e.rota.split('/');
      var info = infoExtra({ sec: a[0], sub: a[1] || null });
      var on = e.rota === k;
      return '<span class="aba extra' + (on ? ' on' : '') + '" data-rota="' + esc(e.rota) + '">' +
        '<a href="#/' + esc(e.rota) + '"' + (on ? ' aria-current="page"' : '') + ' title="' + esc(e.titulo) + '"><i class="ti ' + info.icon + '"></i><span>' + esc(e.titulo) + '</span></a>' +
        '<button type="button" class="x" data-fechar="' + esc(e.rota) + '" aria-label="Fechar ' + esc(e.titulo) + '"><i class="ti ti-x"></i></button></span>';
    }).join('');
  }
  $('abas').innerHTML = html;
  var on = $('abas').querySelector('.aba.on');
  if (on && on.scrollIntoView) on.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  cada('#bnav a[data-sec]', function (a) {
    var sec = a.getAttribute('data-sec');
    a.classList.toggle('on', r.sec === sec || (sec === 'mais' && (r.sec === 'clientes' || r.sec === 'config' || rotaEhExtra(r))));
  });
  cada('#lateral a[data-sec]', function (a) { a.classList.toggle('on', a.getAttribute('data-sec') === r.sec); });
}
$('abas').addEventListener('click', function (e) {
  var b = e.target.closest('[data-fechar]');
  if (b) { e.preventDefault(); e.stopPropagation(); fecharAba(b.getAttribute('data-fechar')); }
});
$('abas').addEventListener('auxclick', function (e) {   // botão do meio fecha a aba, como no navegador
  var a = e.target.closest('.aba.extra');
  if (a && e.button === 1) { e.preventDefault(); fecharAba(a.getAttribute('data-rota')); }
});

// ── Telas antigas: uma janela (iframe) por tela, mantidas abertas ──
var MAX_JANELAS = 6;
function paginaDaRota(r) {
  var s = SECOES[r.sec];
  if (s && s.abas) {
    var sub = r.sub || s.abas[0][0];
    var a = s.abas.filter(function (x) { return x[0] === sub; })[0] || s.abas[0];
    return a[2];
  }
  if (REGISTROS[r.sec]) return REGISTROS[r.sec].pagina + '?abrir=' + encodeURIComponent(r.sub);
  if ((r.sec === 'mais' || r.sec === 'config') && r.sub && SUBPAGINAS[r.sec][r.sub]) return SUBPAGINAS[r.sec][r.sub][1];
  return null;
}
function frames() { return Array.prototype.slice.call(document.querySelectorAll('#janela iframe')); }
function frameDe(pagina) { return frames().filter(function (f) { return f.getAttribute('data-pagina') === pagina; })[0]; }
function removerFrame(pagina) { var f = frameDe(pagina); if (f) f.remove(); }
function frameVisivel() { return frames().filter(function (f) { return !f.hidden; })[0]; }

function mostrarFrame(pagina, extra) {
  document.body.classList.add('com-frame');
  var f = frameDe(pagina);
  if (extra === 'novo') {
    history.replaceState(null, '', '#/producao/pedidos');   // F5 não reabre o formulário
    if (f && f.contentWindow && f.contentWindow.openPedidoPanel) { esconderOutros(f); f.contentWindow.openPedidoPanel(null); return; }
  }
  if (!f) {
    f = document.createElement('iframe');
    f.title = 'Tela do sistema';
    f.setAttribute('data-pagina', pagina);
    f.src = pagina + (extra === 'novo' ? (pagina.indexOf('?') < 0 ? '?' : '&') + 'novo=1' : '');
    $('janela').appendChild(f);
  }
  esconderOutros(f);
  f.setAttribute('data-uso', Date.now());
  // Muitas janelas abertas: fecha a usada há mais tempo (as abas continuam)
  var todas = frames();
  if (todas.length > MAX_JANELAS) {
    todas.sort(function (a, b) { return a.getAttribute('data-uso') - b.getAttribute('data-uso'); });
    todas.slice(0, todas.length - MAX_JANELAS).forEach(function (x) { if (x !== f) x.remove(); });
  }
}
function esconderOutros(f) { frames().forEach(function (x) { x.hidden = x !== f; }); }

function renderSubabas(r) {
  var s = SECOES[r.sec], el = $('subabas');
  if (!s || !s.abas) { el.hidden = true; el.innerHTML = ''; return; }
  var sub = r.sub || s.abas[0][0];
  el.innerHTML = s.abas.map(function (a) {
    return '<a href="#/' + r.sec + '/' + a[0] + '" class="' + (a[0] === sub ? 'on' : '') + '">' + a[1] + '</a>';
  }).join('');
  el.hidden = false;
}

function render() {
  var r = rotaAtual();
  $('avmenu').hidden = true;
  fecharResultados();
  if (rotaEhExtra(r)) garantirExtra(r);
  renderAbas(r);
  var naCasa = r.sec === 'inicio';
  $('barra-busca').hidden = naCasa;          // no Início a busca e o relógio grandes substituem os do topo
  $('hora-topo').hidden = naCasa;
  var pagina = paginaDaRota(r);
  renderSubabas(r);
  if (pagina) { mostrarFrame(pagina, r.extra); return; }
  document.body.classList.remove('com-frame');
  window.scrollTo(0, 0);
  if (r.sec === 'mais') renderMais();
  else if (r.sec === 'config') renderConfig();
  else renderInicio();
}

// ── Relógio e clima ───────────────────────────────────────────
function hhmm(d) { return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0'); }
function dataLonga(d) { var t = DIAS[d.getDay()] + ', ' + d.getDate() + ' de ' + MESES[d.getMonth()]; return t.charAt(0).toUpperCase() + t.slice(1); }
function tic() {
  var d = new Date();
  $('hora-topo').innerHTML = '<span class="dt">' + DIAS[d.getDay()].slice(0, 3) + ', ' + d.getDate() + ' ' + MESES_CURTOS[d.getMonth()] + '</span> ' + hhmm(d);
  var rl = $('relogio'); if (rl) rl.textContent = hhmm(d);
  var sd = $('saud'); if (sd) sd.textContent = saudacao();
}
function saudacao() {
  var h = new Date().getHours(), n = (meta().nome || '').split(' ')[0];
  var s = h >= 5 && h < 12 ? 'Bom dia' : h >= 12 && h < 18 ? 'Boa tarde' : 'Boa noite';
  return s + (n ? ', ' + n : '');
}

// Clima: Open-Meteo (gratuito, sem chave). Guarda 30 min neste aparelho.
var CLIMA_COD = { 0: ['☀️', 'céu limpo'], 1: ['🌤️', 'poucas nuvens'], 2: ['⛅', 'parcialmente nublado'], 3: ['☁️', 'nublado'], 45: ['🌫️', 'neblina'], 48: ['🌫️', 'neblina'],
  51: ['🌦️', 'garoa'], 53: ['🌦️', 'garoa'], 55: ['🌦️', 'garoa'], 61: ['🌧️', 'chuva fraca'], 63: ['🌧️', 'chuva'], 65: ['🌧️', 'chuva forte'],
  80: ['🌦️', 'pancadas de chuva'], 81: ['🌧️', 'pancadas de chuva'], 82: ['⛈️', 'chuva forte'], 95: ['⛈️', 'trovoadas'], 96: ['⛈️', 'trovoadas'], 99: ['⛈️', 'trovoadas'] };
var CLIMA = null;
async function carregarClima(cidade) {
  if (!cidade) { CLIMA = null; mostrarClima(); return; }
  var chave = 'ideali-clima:' + cidade.toLowerCase();
  try {
    var c = lerLocal(chave, null);
    if (!c || Date.now() - c.t > 30 * 60000) {
      var g = await (await fetch('https://geocoding-api.open-meteo.com/v1/search?count=1&language=pt&name=' + encodeURIComponent(cidade))).json();
      var loc = g.results && g.results[0];
      if (!loc) { CLIMA = { erro: 'Cidade não encontrada' }; mostrarClima(); return; }
      var w = await (await fetch('https://api.open-meteo.com/v1/forecast?timezone=auto&forecast_days=1&latitude=' + loc.latitude + '&longitude=' + loc.longitude +
        '&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max')).json();
      c = { t: Date.now(), nome: loc.name, temp: w.current.temperature_2m, cod: w.current.weather_code,
            max: w.daily.temperature_2m_max[0], min: w.daily.temperature_2m_min[0], chuva: w.daily.precipitation_probability_max[0] };
      gravarLocal(chave, c);
    }
    CLIMA = c;
  } catch (e) { CLIMA = { erro: 'Clima indisponível' }; }
  mostrarClima();
}
function climaTexto(longo) {
  if (!CLIMA || CLIMA.erro) return '';
  var d = CLIMA_COD[CLIMA.cod] || ['🌡️', ''];
  if (!longo) return d[0] + ' ' + Math.round(CLIMA.temp) + '°';
  return d[0] + ' ' + Math.round(CLIMA.temp) + '° ' + d[1] + ' em ' + esc(CLIMA.nome) +
    ' (' + Math.round(CLIMA.min) + '° a ' + Math.round(CLIMA.max) + '°' + (CLIMA.chuva >= 30 ? ', ' + CLIMA.chuva + '% de chuva' : '') + ')';
}
function mostrarClima() {
  var el = $('clima-topo');
  if (CLIMA && !CLIMA.erro) { el.innerHTML = climaTexto(false); el.title = climaTexto(true).replace(/<[^>]+>/g, ''); el.hidden = false; }
  else el.hidden = true;
  var cl = $('clima-casa');
  if (cl) cl.innerHTML = CLIMA && !CLIMA.erro ? ' · ' + climaTexto(true)
    : !meta().cidade ? ' · <a href="#/config">informe sua cidade para ver o clima</a>' : CLIMA && CLIMA.erro ? ' · ' + CLIMA.erro : '';
}

// ── Dados do dia (Início e números dos atalhos) ───────────────
// Junta pedidos e ordens CAM em aberto, cada um com o prazo que o sistema já usa hoje:
//  - pedido: data prevista; sem ela, criação + 7 dias úteis (a mesma previsão da tela de Pedidos)
//  - ordem CAM: criação + 6 dias (a tela Ordens CAM fica vermelha a partir de 7 dias)
function somaDiasUteis(d, n) { var x = new Date(d); while (n > 0) { x.setDate(x.getDate() + 1); if (x.getDay() !== 0 && x.getDay() !== 6) n--; } return x; }
function juntarProducao(pedidos, ordens, nomes) {
  var lista = [];
  pedidos.forEach(function (p) {
    var est = !p.data_prevista;
    lista.push({ d: est ? isoLocal(somaDiasUteis(new Date(p.created_at), 7)) : String(p.data_prevista).slice(0, 10), estimado: est,
      nome: nomes[p.cliente_reg] || 'Cliente #' + p.cliente_reg, desc: p.descricao || '—', urgente: p.urgente,
      rota: 'pedido/' + p.id, titulo: 'Pedido #' + p.id });
  });
  ordens.forEach(function (o) {
    if (o.excluido || o.arquivado || o.aceito_pelo_admin === false) return;
    lista.push({ d: isoLocal(somaDias(new Date(o.created_at), 6)), estimado: true,
      nome: o.cliente_nome || nomes[o.cliente_reg] || 'Cliente', desc: 'CAM · ' + (o.descricao || '—'), urgente: false,
      rota: 'cam/' + o.id, titulo: 'CAM #' + o.id });
  });
  return lista.sort(function (a, b) { return a.d < b.d ? -1 : a.d > b.d ? 1 : (b.urgente ? 1 : 0) - (a.urgente ? 1 : 0); });
}
function calcularDevendo(linhas, nomes) {
  var agora = new Date(), mesAtual = agora.getMonth(), anoAtual = agora.getFullYear();
  var total = 0, porCli = {};
  linhas.forEach(function (l) {
    if (l.quitado) return;
    var saldo = Number(l.valor_mes || 0) - Number(l.valor_pago || 0);
    if (saldo <= 0.005) return;
    total += saldo;
    var fechado = l.ano < anoAtual || (l.ano === anoAtual && l.mes < mesAtual);
    if (!fechado) return;
    var c = porCli[l.cliente_reg] = porCli[l.cliente_reg] || { valor: 0, desde: null };
    c.valor += saldo;
    var chave = l.ano * 12 + l.mes;
    if (c.desde == null || chave < c.desde) c.desde = chave;
  });
  var lista = Object.keys(porCli).map(function (reg) {
    return { reg: reg, nome: nomes[reg] || 'Cliente #' + reg, valor: porCli[reg].valor, desde: porCli[reg].desde };
  }).sort(function (a, b) { return b.valor - a.valor; });
  return { total: total, lista: lista };
}
var RESUMO = null, _resumoPromessa = null;
function carregarResumo() {
  if (RESUMO && Date.now() - RESUMO.t < 60000) return Promise.resolve(RESUMO);
  if (_resumoPromessa) return _resumoPromessa;
  _resumoPromessa = Promise.all([
    sb.from('pedidos').select('id,cliente_reg,descricao,status,data_prevista,urgente,valor,created_at').in('status', ['orcamento', 'producao']),
    sb.from('ordens_exocad').select('id,cliente_reg,cliente_nome,descricao,qtd_elementos,status,created_at,excluido,arquivado,aceito_pelo_admin').in('status', ['a_fazer', 'fazendo']),
    sb.from('cadastro_clientes').select('reg,nome'),
    sb.from('controle_mensal').select('cliente_reg,mes,ano,valor_mes,valor_pago,quitado')
  ]).then(function (res) {
    res.forEach(function (x) { if (x.error) throw x.error; });
    var nomes = {};
    res[2].data.forEach(function (c) { nomes[c.reg] = c.nome; });
    var prod = juntarProducao(res[0].data, res[1].data, nomes);
    var hoje = isoLocal(new Date());
    RESUMO = { t: Date.now(), hoje: hoje,
      atrasados: prod.filter(function (p) { return p.d < hoje; }),
      deHoje: prod.filter(function (p) { return p.d === hoje; }),
      devendo: calcularDevendo(res[3].data, nomes) };
    return RESUMO;
  }).finally(function () { _resumoPromessa = null; });
  return _resumoPromessa;
}

// ── Início: relógio, busca grande, atalhos e o cartão "Hoje" ──
var ATALHOS = {
  novo:      { nome: 'Novo pedido',      icon: 'ti-plus',           href: '#/producao/pedidos/novo' },
  atrasados: { nome: 'Atrasados',        icon: 'ti-alarm',          href: '#/producao/pedidos' },
  hoje:      { nome: 'Entregas de hoje', icon: 'ti-truck-delivery', href: '#/producao/pedidos' },
  receber:   { nome: 'A receber',        icon: 'ti-cash',           href: '#/financeiro/receber' },
  producao:  { nome: 'Produção',         icon: 'ti-layout-kanban',  href: '#/producao' },
  clientes:  { nome: 'Clientes',         icon: 'ti-users',          href: '#/clientes' },
  cam:       { nome: 'Ordens CAM',       icon: 'ti-cube',           href: '#/producao/cam' },
  tarefas:   { nome: 'Tarefas',          icon: 'ti-checklist',      href: '#/mais/tarefas' },
  cobranca:  { nome: 'Cobrança e Pix',   icon: 'ti-qrcode',         href: '#/financeiro/cobranca' }
};
var ATALHOS_PADRAO = { ordem: ['novo', 'atrasados', 'hoje', 'receber', 'producao', 'clientes', 'cam', 'tarefas', 'cobranca'], ocultos: ['cam', 'tarefas', 'cobranca'] };
function cfgAtalhos() {
  var c = lerLocal('ideali-atalhos', null);
  if (!c || !Array.isArray(c.ordem)) c = JSON.parse(JSON.stringify(ATALHOS_PADRAO));
  c.ordem = c.ordem.filter(function (k) { return ATALHOS[k]; });
  Object.keys(ATALHOS).forEach(function (k) { if (c.ordem.indexOf(k) < 0) { c.ordem.push(k); (c.ocultos = c.ocultos || []).push(k); } });
  c.ocultos = c.ocultos || [];
  return c;
}
function gravarAtalhos(c) { gravarLocal('ideali-atalhos', c); salvarPrefs({ atalhos: c }); }
var EDITANDO_ATALHOS = false;

function renderInicio() {
  var d = new Date();
  $('main').innerHTML =
    '<section class="casa">' +
      '<div class="relogio" id="relogio">' + hhmm(d) + '</div>' +
      '<div class="saud" id="saud">' + esc(saudacao()) + '</div>' +
      '<div class="data-casa">' + dataLonga(d) + '<span id="clima-casa"></span></div>' +
      '<label class="busca grande" data-busca><i class="ti ti-search lupa" aria-hidden="true"></i>' +
        '<input id="busca-casa" type="search" autocomplete="off" spellcheck="false" aria-label="Buscar" placeholder="Buscar pedido, cliente, paciente ou digitar um comando…"><kbd>Ctrl K</kbd></label>' +
      '<div class="atalhos" id="atalhos"></div>' +
      '<button type="button" class="personalizar" id="personalizar"></button>' +
      '<section class="hoje vidro" id="hoje-card" aria-label="Hoje">' +
        '<div class="tit-hoje"><b>Hoje</b><a href="#/producao">Ver produção →</a></div>' +
        '<div><h3><i class="ti ti-alarm"></i> Atrasados <span class="n" id="h-atr">…</span></h3><ul id="h-atr-l"></ul></div>' +
        '<div><h3><i class="ti ti-truck-delivery"></i> Entregas de hoje <span class="n" id="h-hoje">…</span></h3><ul id="h-hoje-l"></ul></div>' +
        '<div><h3><i class="ti ti-receipt"></i> Quem está devendo <span class="n" id="h-dev">…</span></h3><ul id="h-dev-l"></ul></div>' +
      '</section>' +
    '</section>';
  ligarBusca($('busca-casa'));
  mostrarClima();
  renderAtalhos();
  $('personalizar').addEventListener('click', function () { EDITANDO_ATALHOS = !EDITANDO_ATALHOS; renderAtalhos(); });
  carregarResumo().then(function (R) {
    if (rotaAtual().sec !== 'inicio') return;
    renderAtalhos();
    renderHoje(R);
  }).catch(function (e) {
    console.error('[inicio]', e);
    ['h-atr', 'h-hoje', 'h-dev'].forEach(function (id) { $(id).textContent = '—'; });
    $('h-atr-l').innerHTML = '<li class="vazio">Não deu para carregar agora. Atualize a página.</li>';
  });
}

function renderAtalhos() {
  var el = $('atalhos'); if (!el) return;
  var c = cfgAtalhos(), R = RESUMO;
  el.classList.toggle('editando', EDITANDO_ATALHOS);
  el.innerHTML = c.ordem.filter(function (k) { return EDITANDO_ATALHOS || c.ocultos.indexOf(k) < 0; }).map(function (k) {
    var a = ATALHOS[k], oculto = c.ocultos.indexOf(k) >= 0, extra = '';
    if (R && k === 'atrasados') extra = '<span class="num' + (R.atrasados.length ? ' alerta' : '') + '">' + R.atrasados.length + '</span>';
    if (R && k === 'hoje') extra = '<span class="num">' + R.deHoje.length + '</span>';
    var val = R && k === 'receber' ? '<span class="val">' + brlCurto(R.devendo.total) + '</span>' : '';
    return '<a class="atalho vidro' + (oculto ? ' oculto' : '') + '" href="' + a.href + '" data-k="' + k + '"' + (EDITANDO_ATALHOS ? ' draggable="true"' : '') + '>' +
      extra + '<span class="ic"><i class="ti ' + a.icon + '"></i></span><span class="nm">' + a.nome + '</span>' + val +
      '<span class="ed">' +
        '<button type="button" data-mover="-1" aria-label="Mover ' + a.nome + ' para a esquerda"><i class="ti ti-chevron-left"></i></button>' +
        '<button type="button" data-ver aria-label="' + (oculto ? 'Mostrar ' : 'Esconder ') + a.nome + '"><i class="ti ' + (oculto ? 'ti-eye-off' : 'ti-eye') + '"></i></button>' +
        '<button type="button" data-mover="1" aria-label="Mover ' + a.nome + ' para a direita"><i class="ti ti-chevron-right"></i></button>' +
      '</span></a>';
  }).join('');
  $('personalizar').innerHTML = EDITANDO_ATALHOS ? '<i class="ti ti-check"></i> Concluir' : '<i class="ti ti-adjustments-horizontal"></i> Personalizar atalhos';
}
// Edição dos atalhos: setas e olho (funciona no celular) + arrastar (computador)
document.addEventListener('click', function (e) {
  var at = e.target.closest('.atalhos.editando .atalho');
  if (!at) return;
  e.preventDefault();
  var b = e.target.closest('button'); if (!b) return;
  var c = cfgAtalhos(), k = at.getAttribute('data-k');
  if (b.hasAttribute('data-ver')) {
    var i = c.ocultos.indexOf(k);
    if (i >= 0) c.ocultos.splice(i, 1); else c.ocultos.push(k);
  } else {
    var de = c.ordem.indexOf(k), para = de + Number(b.getAttribute('data-mover'));
    if (para < 0 || para >= c.ordem.length) return;
    c.ordem.splice(de, 1); c.ordem.splice(para, 0, k);
  }
  gravarAtalhos(c); renderAtalhos();
  var foco = document.querySelector('.atalho[data-k="' + k + '"] [' + (b.hasAttribute('data-ver') ? 'data-ver' : 'data-mover="' + b.getAttribute('data-mover') + '"') + ']');
  if (foco) foco.focus();
});
var _arrastando = null;
document.addEventListener('dragstart', function (e) {
  var at = e.target.closest && e.target.closest('.atalhos.editando .atalho'); if (!at) return;
  _arrastando = at.getAttribute('data-k'); at.classList.add('arrastando');
  e.dataTransfer.effectAllowed = 'move'; try { e.dataTransfer.setData('text/plain', _arrastando); } catch (x) {}
});
document.addEventListener('dragover', function (e) { if (_arrastando && e.target.closest('.atalhos.editando .atalho')) e.preventDefault(); });
document.addEventListener('drop', function (e) {
  var alvo = e.target.closest('.atalhos.editando .atalho'); if (!_arrastando || !alvo) return;
  e.preventDefault();
  var c = cfgAtalhos(), k = alvo.getAttribute('data-k');
  if (k !== _arrastando) { c.ordem.splice(c.ordem.indexOf(_arrastando), 1); c.ordem.splice(c.ordem.indexOf(k), 0, _arrastando); gravarAtalhos(c); }
  _arrastando = null; renderAtalhos();
});
document.addEventListener('dragend', function () { if (_arrastando) { _arrastando = null; renderAtalhos(); } });

function renderHoje(R) {
  function item(p, etiqueta, cls) {
    return '<li><a href="#/' + p.rota + '" data-titulo="' + esc(p.titulo) + '"><span class="t">' + (p.urgente ? '🔥 ' : '') + esc(p.nome) + ' · ' + esc(p.desc) + '</span>' +
      '<span class="v' + (cls ? ' ' + cls : '') + '">' + etiqueta + '</span></a></li>';
  }
  $('h-atr').textContent = R.atrasados.length;
  $('h-atr').classList.toggle('alerta', R.atrasados.length > 0);
  $('h-atr-l').innerHTML = R.atrasados.length ? R.atrasados.slice(0, 3).map(function (p) { return item(p, diasEntre(p.d, R.hoje) + 'd', 'urg'); }).join('') +
    (R.atrasados.length > 3 ? '<li class="vazio">e mais ' + (R.atrasados.length - 3) + '</li>' : '') : '<li class="vazio">Nenhum pedido atrasado 👍</li>';
  $('h-hoje').textContent = R.deHoje.length;
  $('h-hoje-l').innerHTML = R.deHoje.length ? R.deHoje.slice(0, 3).map(function (p) { return item(p, p.estimado ? 'previsto' : 'hoje'); }).join('') +
    (R.deHoje.length > 3 ? '<li class="vazio">e mais ' + (R.deHoje.length - 3) + '</li>' : '') : '<li class="vazio">Nada para entregar hoje.</li>';
  var dv = R.devendo;
  $('h-dev').textContent = brlCurto(dv.total);
  $('h-dev-l').innerHTML = dv.lista.length ? dv.lista.slice(0, 3).map(function (c) {
    return '<li><a href="#/cliente/' + encodeURIComponent(c.reg) + '" data-titulo="' + esc(c.nome) + '"><span class="t">' + esc(c.nome) + '</span><span class="v">' + brl(c.valor) + '</span></a></li>';
  }).join('') : '<li class="vazio">Ninguém devendo de meses anteriores.</li>';
}
// Links com data-titulo abrem a aba já com o nome certo
document.addEventListener('click', function (e) {
  var a = e.target.closest('a[data-titulo]');
  if (!a || e.ctrlKey || e.metaKey) return;
  e.preventDefault();
  abrirAba(a.getAttribute('href').replace(/^#\//, ''), a.getAttribute('data-titulo'));
});

// ── Busca em tudo (pedidos, clientes, ordens CAM e comandos) ──
var COMANDOS = [
  ['Novo pedido', 'ti-plus', '#/producao/pedidos/novo', 'criar adicionar'],
  ['Pedidos', 'ti-file-text', '#/producao/pedidos', 'producao'],
  ['Ordens CAM', 'ti-cube', '#/producao/cam', 'exocad producao'],
  ['Dentistas e clínicas', 'ti-users', '#/clientes/cadastro', 'clientes cadastro'],
  ['Portal e convites', 'ti-link', '#/clientes/portal', 'clientes acesso'],
  ['A receber', 'ti-cash', '#/financeiro/receber', 'financeiro devendo'],
  ['Pagamentos Inove', 'ti-building-bank', '#/financeiro/inove', 'financeiro'],
  ['Cobrança e Pix', 'ti-qrcode', '#/financeiro/cobranca', 'financeiro cobrar'],
  ['Recibos', 'ti-receipt', '#/financeiro/recibos', 'financeiro'],
  ['Gastos de entrega', 'ti-motorbike', '#/financeiro/gastos', 'financeiro motoboy'],
  ['Relatório do mês', 'ti-report-money', '#/financeiro/relatorio', 'financeiro'],
  ['Tarefas', 'ti-checklist', '#/mais/tarefas', 'lembretes'],
  ['Orçamentos', 'ti-file-dollar', '#/mais/orcamento', ''],
  ['Relatórios', 'ti-report', '#/mais/relatorios', 'pdf'],
  ['Painel completo', 'ti-chart-bar', '#/mais/painel', 'graficos'],
  ['Dashboard', 'ti-chart-pie', '#/mais/dashboard', ''],
  ['Inove 3D', 'ti-cube', '#/mais/inove-3d', ''],
  ['Configurações', 'ti-settings', '#/config', 'ajustes perfil'],
  ['Trocar o fundo', 'ti-photo', '#/config', 'aparencia tema foto paisagem'],
  ['Tabela de preços', 'ti-currency-real', '#/config/precos', 'valores'],
  ['Minha conta', 'ti-lock', '#/config/conta', 'senha duas etapas'],
  ['Modo claro ou escuro', 'ti-moon', function () { aplicarAparencia(escuroAgora() ? 'claro' : 'escuro'); }, 'tema noite'],
  ['Comando rápido IA', 'ti-sparkles', function () { abrirIA(''); }, 'inteligencia assistente'],
  ['Sair', 'ti-logout', function () { idealiSair(); }, 'logout']
];
var STATUS_TXT = { orcamento: 'orçamento', producao: 'em produção', a_fazer: 'a fazer', fazendo: 'fazendo', finalizado: 'finalizado', entregue: 'entregue' };
function norm(s) { return String(s == null ? '' : s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }
var BUSCA = null, _buscaPromessa = null;
function carregarBusca() {
  if (BUSCA && Date.now() - BUSCA.t < 120000) return Promise.resolve(BUSCA);
  if (_buscaPromessa) return _buscaPromessa;
  _buscaPromessa = Promise.all([
    sb.from('cadastro_clientes').select('reg,nome,cidade,tel'),
    sb.from('pedidos').select('id,cliente_reg,descricao,status,created_at').order('created_at', { ascending: false }).limit(1500),
    sb.from('ordens_exocad').select('id,cliente_reg,cliente_nome,descricao,status,created_at,excluido').order('created_at', { ascending: false }).limit(1500)
  ]).then(function (res) {
    res.forEach(function (x) { if (x.error) throw x.error; });
    var nomes = {};
    res[0].data.forEach(function (c) { nomes[c.reg] = c.nome; });
    BUSCA = { t: Date.now(),
      clientes: res[0].data.map(function (c) { return { c: c, h: norm([c.nome, c.cidade, c.tel].join(' ')) }; }),
      pedidos: res[1].data.map(function (p) { var n = nomes[p.cliente_reg] || ''; return { p: p, n: n, h: norm(['#' + p.id, p.id, p.descricao, n].join(' ')) }; }),
      ordens: res[2].data.filter(function (o) { return !o.excluido; }).map(function (o) { var n = o.cliente_nome || nomes[o.cliente_reg] || ''; return { o: o, n: n, h: norm(['#' + o.id, o.id, o.descricao, n, 'cam'].join(' ')) }; }) };
    return BUSCA;
  }).finally(function () { _buscaPromessa = null; });
  return _buscaPromessa;
}
function marcar(txt, palavras) {
  var s = esc(txt);
  palavras.forEach(function (w) {
    if (w.length < 2) return;
    var re = new RegExp('(' + w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'ig');
    s = s.replace(re, '<mark>$1</mark>');
  });
  return s;
}
var BUSCA_INPUT = null, RES_ITENS = [], RES_SEL = 0;
function ligarBusca(input) {
  if (!input || input._ligado) return;
  input._ligado = true;
  input.addEventListener('focus', function () { BUSCA_INPUT = input; carregarBusca().catch(function () {}); buscar(); });
  input.addEventListener('input', function () { BUSCA_INPUT = input; buscar(); });
  input.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      if (!RES_ITENS.length) return;
      RES_SEL = (RES_SEL + (e.key === 'ArrowDown' ? 1 : -1) + RES_ITENS.length) % RES_ITENS.length;
      cada('#resultados .res', function (b, i) { b.classList.toggle('sel', i === RES_SEL); if (i === RES_SEL) b.scrollIntoView({ block: 'nearest' }); });
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (RES_ITENS[RES_SEL]) executar(RES_ITENS[RES_SEL]);
    } else if (e.key === 'Escape') { input.value = ''; fecharResultados(); input.blur(); }
  });
}
async function buscar() {
  var input = BUSCA_INPUT; if (!input) return;
  var q = input.value.trim(), palavras = norm(q).split(/\s+/).filter(Boolean);
  var bate = function (h) { return palavras.every(function (w) { return h.indexOf(w) >= 0; }); };
  var grupos = [];
  var cmds = COMANDOS.filter(function (c) { return !palavras.length ? ['Novo pedido', 'Pedidos', 'A receber', 'Trocar o fundo'].indexOf(c[0]) >= 0 : bate(norm(c[0] + ' ' + c[3])); })
    .slice(0, palavras.length ? 5 : 4).map(function (c) { return { ic: c[1], t: c[0], acao: c[2] }; });
  if (palavras.length) {
    var B = BUSCA;
    if (!B) { try { B = await carregarBusca(); } catch (e) { B = null; } if (input.value.trim() !== q) return; }
    if (B) {
      var cli = B.clientes.filter(function (x) { return bate(x.h); }).slice(0, 5).map(function (x) {
        return { ic: 'ti-user', t: x.c.nome, s: [x.c.cidade, x.c.tel].filter(Boolean).join(' · '), rota: 'cliente/' + x.c.reg, titulo: x.c.nome };
      });
      var ped = B.pedidos.filter(function (x) { return bate(x.h); }).slice(0, 5).map(function (x) {
        return { ic: 'ti-file-text', t: 'Pedido #' + x.p.id + (x.n ? ' · ' + x.n : ''), s: x.p.descricao || '', tag: STATUS_TXT[x.p.status] || x.p.status, rota: 'pedido/' + x.p.id, titulo: 'Pedido #' + x.p.id };
      });
      var cam = B.ordens.filter(function (x) { return bate(x.h); }).slice(0, 5).map(function (x) {
        return { ic: 'ti-cube', t: 'CAM #' + x.o.id + (x.n ? ' · ' + x.n : ''), s: x.o.descricao || '', tag: STATUS_TXT[x.o.status] || x.o.status, rota: 'cam/' + x.o.id, titulo: 'CAM #' + x.o.id };
      });
      if (cli.length) grupos.push(['Clientes', cli]);
      if (ped.length) grupos.push(['Pedidos', ped]);
      if (cam.length) grupos.push(['Ordens CAM', cam]);
    } else grupos.push(['Busca', [{ ic: 'ti-cloud-off', t: 'Não deu para buscar agora', s: 'Confira a internet e tente de novo', acao: function () {} }]]);
  }
  if (cmds.length) grupos.unshift([palavras.length ? 'Comandos' : 'Sugestões', cmds]);
  if (q.length >= 3) grupos.push(['Inteligência artificial', [{ ic: 'ti-sparkles', t: 'Pedir à IA: “' + q + '”', s: 'Abre o Comando rápido IA com este texto', acao: function () { abrirIA(q); } }]]);
  mostrarResultados(grupos, palavras);
}
function mostrarResultados(grupos, palavras) {
  var el = $('resultados'), html = '';
  RES_ITENS = []; RES_SEL = 0;
  grupos.forEach(function (g) {
    html += '<div class="grp">' + g[0] + '</div>';
    g[1].forEach(function (it) {
      var i = RES_ITENS.push(it) - 1;
      html += '<button type="button" class="res' + (i === 0 ? ' sel' : '') + '" role="option" data-i="' + i + '"><span class="ic"><i class="ti ' + it.ic + '"></i></span>' +
        '<span class="tx"><b>' + marcar(it.t, palavras) + '</b>' + (it.s ? '<small>' + marcar(it.s, palavras) + '</small>' : '') + '</span>' +
        (it.tag ? '<span class="tag">' + esc(it.tag) + '</span>' : '') + '</button>';
    });
  });
  if (!RES_ITENS.length) html = '<div class="nada">Nada encontrado.</div>';
  el.innerHTML = html;
  posicionarResultados();
  el.hidden = false;
}
function posicionarResultados() {
  var el = $('resultados'); if (!BUSCA_INPUT) return;
  var r = BUSCA_INPUT.closest('[data-busca]').getBoundingClientRect();
  el.style.left = r.left + 'px'; el.style.width = r.width + 'px'; el.style.top = (r.bottom + 6) + 'px';
}
function fecharResultados() { $('resultados').hidden = true; }
function executar(it) {
  fecharResultados();
  if (BUSCA_INPUT) { BUSCA_INPUT.value = ''; BUSCA_INPUT.blur(); }
  if (it.rota) abrirAba(it.rota, it.titulo);
  else if (typeof it.acao === 'function') it.acao();
  else if (it.acao) location.hash = it.acao;
}
$('resultados').addEventListener('mousedown', function (e) { e.preventDefault(); });   // não tira o foco da busca
$('resultados').addEventListener('click', function (e) {
  var b = e.target.closest('.res'); if (b) executar(RES_ITENS[Number(b.getAttribute('data-i'))]);
});
document.addEventListener('focusout', function () { setTimeout(function () { if (!document.activeElement || !document.activeElement.closest('[data-busca]')) fecharResultados(); }, 0); });
window.addEventListener('resize', function () { if (!$('resultados').hidden) posicionarResultados(); });
document.addEventListener('keydown', function (e) {
  var digitando = /INPUT|TEXTAREA|SELECT/.test((document.activeElement || {}).tagName || '');
  if (((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') || (e.key === '/' && !digitando)) {
    e.preventDefault();
    var alvo = $('busca-casa') && rotaAtual().sec === 'inicio' ? $('busca-casa') : $('busca-topo');
    alvo.focus(); alvo.select();
  }
});
// Ctrl+K também funciona com o foco dentro de uma tela antigo (iframe)
function ouvirAtalhosNoFrame(f) {
  try {
    f.contentWindow.document.addEventListener('keydown', function (e) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); $('busca-topo').focus(); }
    });
  } catch (x) {}
}
new MutationObserver(function (ms) {
  ms.forEach(function (m) { m.addedNodes.forEach(function (n) { if (n.tagName === 'IFRAME') n.addEventListener('load', function () { ouvirAtalhosNoFrame(n); }); }); });
}).observe($('janela'), { childList: true });

// ── IA: abre o "Comando Rápido IA" das telas antigas ──────────
function abrirIA(texto) {
  function tenta(f) {
    var w = f && f.contentWindow;
    if (!w || !w.openIAPanel || !w.document.getElementById('ia-panel')) return false;
    w.openIAPanel();
    var i = w.document.getElementById('ia-input');
    if (i && texto) { i.value = texto; i.focus(); }
    return true;
  }
  if (tenta(frameVisivel()) && document.body.classList.contains('com-frame')) return;
  location.hash = '#/producao/pedidos';
  var n = 0, t = setInterval(function () {
    if (tenta(frameDe('pedidos.html')) || ++n > 40) clearInterval(t);
  }, 250);
}

// ── Barra lateral fina (computador) ───────────────────────────
function lateralLigada() { try { return localStorage.getItem('ideali-lateral') !== '0'; } catch (e) { return true; } }
function aplicarLateral(ligada) {
  try { localStorage.setItem('ideali-lateral', ligada ? '1' : '0'); } catch (e) {}
  $('lateral').hidden = !ligada;
  document.body.classList.toggle('com-lateral', ligada);
  atualizarBotoesMenu();
}
$('lat-esconder').addEventListener('click', function () { aplicarLateral(false); });
$('lat-ia').addEventListener('click', function () { abrirIA(''); });

// ── Mais ──────────────────────────────────────────────────────
function renderMais() {
  function card(href, icon, titulo, frase, extra) {
    return '<a class="mcard vidro' + (extra || '') + '" ' + (href ? 'href="' + href + '"' : '') + '>' +
      '<span class="ic"><i class="ti ' + icon + '"></i></span><span><b>' + titulo + '</b><span>' + frase + '</span></span></a>';
  }
  $('main').innerHTML =
    '<h1 class="titulo-pg">Mais</h1><p class="sub-pg">Tudo o que não está nas abas principais.</p>' +
    '<p class="secao">Do dia a dia</p><div class="cards">' +
      card('#/clientes', 'ti-users', 'Clientes', 'Dentistas e clínicas, cadastro e acesso ao portal.') +
      card('#/mais/tarefas', 'ti-checklist', 'Tarefas', 'Lembretes e pendências do laboratório.') +
      card('#/mais/orcamento', 'ti-file-dollar', 'Orçamentos', 'Monte um orçamento pela tabela de preços.') +
      card('#/mais/relatorios', 'ti-report', 'Relatórios', 'Relatórios em PDF de vendas e pagamentos.') +
    '</div>' +
    '<p class="secao">Painéis</p><div class="cards">' +
      card('#/mais/painel', 'ti-chart-bar', 'Painel completo', 'Gráficos de produção, clientes e financeiro do mês.') +
      card('#/mais/dashboard', 'ti-chart-pie', 'Dashboard', 'Visão geral com indicadores.') +
      card('#/mais/resumo', 'ti-list-details', 'Resumo', 'Resumo rápido de tarefas e pedidos Inove.') +
    '</div>' +
    '<p class="secao">Inove</p><div class="cards">' +
      card('#/mais/inove-3d', 'ti-cube', 'Inove 3D', 'Pedidos da Inove por cliente.') +
      card('#/mais/inove', 'ti-calendar-stats', 'Inove: controle mensal', 'Controle mês a mês da Inove 3D.') +
    '</div>' +
    '<p class="secao">Outros sistemas</p><div class="cards">' +
      card('estudio-cad.html" target="_blank" rel="noopener', 'ti-ruler-2', 'Estúdio CAD', 'Desenhos CAD avulsos. Abre em outra aba.') +
    '</div>' +
    '<p class="secao">Em breve</p><div class="cards">' +
      card('', 'ti-messages', 'Equipe de IA', 'Ana, Bia, Mika, Klose e o Sr. Otávio de olho no laboratório.', ' breve') +
      card('', 'ti-target-arrow', 'Metas', 'Meta do mês com medalhas e presentes.', ' breve') +
      card('', 'ti-chart-dots-3', 'Análises', 'Gargalos, prazo cumprido e saúde do negócio.', ' breve') +
      card('', 'ti-trophy', 'Ranking de clientes', 'Quem manda mais e quem sumiu.', ' breve') +
    '</div>';
}

// ── Configurações (só pelo menu do avatar) ────────────────────
function renderConfig() {
  var m = meta(), a = aparencia(), fa = fundoAtual();
  var temMinha = !!(MINHA_FOTO || (lerLocal('ideali-fundo-minha', null) || {}).url);
  function miniCss(f) {
    if (f.tipo === 'foto') return 'background-image:url(assets/fundos/' + f.id + '-mini.jpg)';
    if (f.tipo === 'minha') return temMinha ? 'background-image:url(' + (MINHA_FOTO || lerLocal('ideali-fundo-minha', {}).url) + ')' : '';
    return 'background:' + (f.css === 'none' ? f.cor : f.css);
  }
  var galeria = FUNDOS.map(function (f) {
    var minhaVazia = f.tipo === 'minha' && !temMinha;
    return '<button type="button" class="tema' + (f.id === fa ? ' on' : '') + '" data-fundo="' + f.id + '" aria-pressed="' + (f.id === fa) + '">' +
      '<span class="mini' + (minhaVazia ? ' minha' : '') + '" style="' + miniCss(f) + '">' + (minhaVazia ? '<i class="ti ti-upload"></i>' : '') + '</span>' +
      '<b>' + esc(f.nome) + '</b><small>' + (f.tipo === 'foto' ? 'Foto: ' + esc(f.autor) + ' / Pexels' : f.tipo === 'degrade' ? 'Degradê' : f.tipo === 'solida' ? 'Cor sólida' : temMinha ? 'Toque para usar' : 'Envie uma foto sua') + '</small></button>';
  }).join('');
  $('main').innerHTML =
    '<h1 class="titulo-pg">Configurações</h1><p class="sub-pg">Aparência, perfil e cadastros do laboratório.</p>' +
    '<div class="painel card" style="margin-top:16px" id="aparencia">' +
      '<h2><i class="ti ti-palette"></i> Aparência</h2><p class="sub">Automático segue o modo do seu celular ou computador.</p>' +
      '<div class="seg" style="margin-top:12px" id="seg-tema">' +
        ['auto', 'claro', 'escuro'].map(function (k) { return '<button type="button" data-k="' + k + '" class="' + (a === k ? 'on' : '') + '">' + { auto: 'Automático', claro: 'Claro', escuro: 'Escuro' }[k] + '</button>'; }).join('') +
      '</div>' +
      '<h3 style="margin-top:20px">Fundo</h3><p class="sub">Fotos do Pexels, de uso livre. O nome de quem fotografou aparece embaixo de cada uma.</p>' +
      '<div class="galeria" id="galeria">' + galeria + '</div>' +
      '<div style="margin-top:14px;display:flex;align-items:center;gap:10px;flex-wrap:wrap">' +
        '<label class="btn sm" for="minha-foto"><i class="ti ti-upload"></i> ' + (temMinha ? 'Trocar minha foto' : 'Usar minha foto') + '</label>' +
        '<input type="file" id="minha-foto" accept="image/*" hidden>' +
        '<span class="sub" id="minha-msg">Fica guardada só na sua conta. Reduzimos para até 300 KB antes de enviar.</span>' +
      '</div>' +
    '</div>' +
    '<div class="grid2" style="margin-top:16px">' +
      '<div class="painel card"><h2><i class="ti ti-user"></i> Perfil</h2><p class="sub">Aparece na saudação do Início.</p>' +
        '<form class="form" id="f-perfil" style="margin-top:14px">' +
          '<div class="campo"><label for="p-nome">Seu nome</label><input id="p-nome" autocomplete="name" value="' + esc(m.nome || '') + '" placeholder="Ex.: Daniel"></div>' +
          '<div class="campo"><label for="p-cidade">Cidade do laboratório</label><input id="p-cidade" autocomplete="address-level2" value="' + esc(m.cidade || '') + '" placeholder="Ex.: São Paulo">' +
            '<p class="dica">Usada só para mostrar o clima.</p></div>' +
          '<div><button class="btn pri" type="submit">Salvar</button> <span class="aviso-ok" id="p-ok"></span></div>' +
        '</form></div>' +
      '<div style="display:grid;gap:16px">' +
        '<div class="painel card"><h2><i class="ti ti-layout"></i> Tela</h2>' +
          '<label class="chave" style="margin-top:8px"><span><b>Barra lateral</b><small>Ícones de acesso rápido à esquerda (computador).</small></span><input type="checkbox" id="c-lateral"' + (lateralLigada() ? ' checked' : '') + '></label>' +
          '<label class="chave"><span><b>Vidro embaçado</b><small>Desligue se o aparelho ficar lento. O vidro fica mais sólido.</small></span><input type="checkbox" id="c-blur"' + (document.documentElement.classList.contains('sem-blur') ? '' : ' checked') + '></label>' +
        '</div>' +
        '<div class="painel card"><h2><i class="ti ti-settings"></i> Cadastros e conta</h2><div class="cards" style="margin-top:12px;grid-template-columns:1fr">' +
          '<a class="mcard" href="#/config/precos"><span class="ic"><i class="ti ti-currency-real"></i></span><span><b>Tabela de preços</b><span>Valores por tipo de trabalho e material.</span></span></a>' +
          '<a class="mcard" href="#/config/conta"><span class="ic"><i class="ti ti-lock"></i></span><span><b>Minha conta</b><span>Trocar senha e verificação em duas etapas.</span></span></a>' +
          '<a class="mcard breve"><span class="ic"><i class="ti ti-tools"></i></span><span><b>Tipos de trabalho e prazos</b><span>Em breve, junto com a nova Produção.</span></span></a>' +
          '<a class="mcard breve"><span class="ic"><i class="ti ti-trash"></i></span><span><b>Lixeira</b><span>Em breve.</span></span></a>' +
        '</div></div>' +
      '</div>' +
    '</div>';
  $('f-perfil').addEventListener('submit', async function (e) {
    e.preventDefault();
    var nome = $('p-nome').value.trim(), cidade = $('p-cidade').value.trim();
    var r = await sb.auth.updateUser({ data: { nome: nome, cidade: cidade } });
    if (r.error) { $('p-ok').className = 'aviso-erro'; $('p-ok').textContent = 'Não deu para salvar. Tente de novo.'; return; }
    USUARIO = r.data.user;
    await carregarUsuario();
    carregarClima(cidade);
    $('p-ok').className = 'aviso-ok'; $('p-ok').textContent = 'Salvo ✓';
  });
  cada('#seg-tema button', function (b) {
    b.addEventListener('click', function () {
      aplicarAparencia(b.getAttribute('data-k'));
      cada('#seg-tema button', function (x) { x.classList.toggle('on', x === b); });
    });
  });
  cada('#galeria .tema', function (b) {
    b.addEventListener('click', function () {
      var id = b.getAttribute('data-fundo');
      if (id === 'minha' && !temMinha) { $('minha-foto').click(); return; }
      aplicarFundo(id);
      salvarPrefs({ fundo: id });
      cada('#galeria .tema', function (x) { x.classList.toggle('on', x === b); x.setAttribute('aria-pressed', x === b); });
    });
  });
  $('minha-foto').addEventListener('change', function () { if (this.files[0]) enviarMinhaFoto(this.files[0]); });
  $('c-lateral').addEventListener('change', function () { aplicarLateral(this.checked); });
  $('c-blur').addEventListener('change', function () {
    document.documentElement.classList.toggle('sem-blur', !this.checked);
    try { localStorage.setItem('ideali-sem-blur', this.checked ? '0' : '1'); } catch (e) {}
  });
}

// "Usar minha foto": reduz no aparelho (até ~300 KB) e guarda no armazenamento privado da conta
function blobParaDataUrl(b) { return new Promise(function (ok, erro) { var r = new FileReader(); r.onload = function () { ok(r.result); }; r.onerror = erro; r.readAsDataURL(b); }); }
function carregarImagem(file) {
  return new Promise(function (ok, erro) {
    var img = new Image(), url = URL.createObjectURL(file);
    img.onload = function () { URL.revokeObjectURL(url); ok(img); };
    img.onerror = function () { URL.revokeObjectURL(url); erro(new Error('imagem inválida')); };
    img.src = url;
  });
}
async function reduzirFoto(file, limite) {
  var img = await carregarImagem(file);
  var escala = Math.min(1, 1920 / Math.max(img.naturalWidth, img.naturalHeight));
  for (var tentativa = 0; tentativa < 5; tentativa++) {
    var c = document.createElement('canvas');
    c.width = Math.round(img.naturalWidth * escala); c.height = Math.round(img.naturalHeight * escala);
    c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
    for (var q = 0.82; q >= 0.5; q -= 0.08) {
      var b = await new Promise(function (ok) { c.toBlob(ok, 'image/jpeg', q); });
      if (b && b.size <= limite) return b;
    }
    escala *= 0.8;
  }
  throw new Error('foto grande demais');
}
async function enviarMinhaFoto(file) {
  function aviso(t, erro) { var msg = $('minha-msg'); if (msg) { msg.className = erro ? 'aviso-erro' : 'sub'; msg.textContent = t; } }
  if (!/^image\//.test(file.type)) { aviso('Escolha um arquivo de imagem (JPG, PNG…).', true); return; }
  aviso('Reduzindo a foto…');
  try {
    var blob = await reduzirFoto(file, 300 * 1024);
    aviso('Enviando (' + Math.round(blob.size / 1024) + ' KB)…');
    var r = await sb.storage.from('fundos').upload(USUARIO.id + '/fundo.jpg', blob, { upsert: true, contentType: 'image/jpeg', cacheControl: '60' });
    if (r.error) { console.error('[fundo]', r.error); aviso('Não deu para guardar a foto na sua conta. O armazenamento de fundos ainda não foi ativado no banco.', true); return; }
    var v = Date.now();
    MINHA_FOTO = await blobParaDataUrl(blob);
    gravarLocal('ideali-fundo-minha', { v: v, url: MINHA_FOTO });
    aplicarFundo('minha');
    salvarPrefs({ fundo: 'minha', fundo_minha_v: v });
    renderConfig();
    aviso('Pronto! Sua foto virou o fundo ✓');
  } catch (e) { console.error('[fundo]', e); aviso('Não deu para usar essa foto. Tente outra.', true); }
}

// ── Menu do avatar ────────────────────────────────────────────
function atualizarBotoesMenu() {
  var e = escuroAgora();
  $('av-tema').innerHTML = '<i class="ti ' + (e ? 'ti-sun' : 'ti-moon') + '"></i> <span>' + (e ? 'Modo claro' : 'Modo escuro') + '</span>';
  var l = lateralLigada();
  $('av-lateral').innerHTML = '<i class="ti ti-layout-sidebar"></i> <span>' + (l ? 'Esconder barra lateral' : 'Mostrar barra lateral') + '</span>';
}
$('av').addEventListener('click', function (e) {
  e.stopPropagation();
  var m = $('avmenu'), r = $('av').getBoundingClientRect();
  m.style.top = (r.bottom + 8) + 'px';
  m.hidden = !m.hidden;
});
document.addEventListener('click', function (e) { if (!$('avmenu').hidden && !$('avmenu').contains(e.target)) $('avmenu').hidden = true; });
$('av-tema').addEventListener('click', function () { aplicarAparencia(escuroAgora() ? 'claro' : 'escuro'); $('avmenu').hidden = true; });
$('av-lateral').addEventListener('click', function () { aplicarLateral(!lateralLigada()); $('avmenu').hidden = true; });

// ── Início do app ─────────────────────────────────────────────
(async function boot() {
  if (window.IDEALI_SEM_SESSAO) return;          // auth.js está mostrando a tela de login
  // Aparelho fraco (celular com pouca memória): vidro sem desfoque, a não ser que o usuário tenha escolhido
  try {
    if (localStorage.getItem('ideali-sem-blur') == null && navigator.deviceMemory && navigator.deviceMemory <= 2)
      document.documentElement.classList.add('sem-blur');
  } catch (e) {}
  sincronizarTemaAntigo(false);
  aplicarLateral(lateralLigada());
  ligarBusca($('busca-topo'));
  tic(); setInterval(tic, 10000);
  await carregarUsuario();
  window.addEventListener('hashchange', render);
  render();
  carregarClima(meta().cidade);
  sincronizarPrefs().catch(function (e) { console.error('[prefs]', e); });
})();
