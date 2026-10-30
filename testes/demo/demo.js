// ================================================================
// MODO DEMONSTRAÇÃO — Supabase simulado no navegador (dados fictícios)
// Injetado pelo testes/demo/servidor_demo.py antes de qualquer outro script.
// Toda chamada para o Supabase é respondida aqui; o servidor ainda manda uma
// regra de segurança (CSP) que faz o navegador BLOQUEAR qualquer conexão real
// com *.supabase.co. Os dados ficam no localStorage deste endereço (localhost).
// ================================================================
(function () {
  if (window.__idealiDemo) return;
  window.__idealiDemo = true;

  var REF = 'alqhhgysvehtgkwsxeok', HOST = REF + '.supabase.co', CHAVE_DB = 'ideali-demo-db';
  var UID = '00000000-0000-0000-0000-000000000001';

  // ── Sessão fictícia de dono ──
  function b64u(o) { return btoa(unescape(encodeURIComponent(JSON.stringify(o)))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); }
  var agora = Math.floor(Date.now() / 1000);
  var USER = { id: UID, aud: 'authenticated', role: 'authenticated', email: 'demonstracao@exemplo.com',
    app_metadata: { papel: 'dono' }, user_metadata: { nome: 'Demonstração', cidade: 'São Paulo' }, factors: [] };
  var JWT = b64u({ alg: 'HS256', typ: 'JWT' }) + '.' + b64u({ sub: UID, aal: 'aal1', role: 'authenticated', exp: agora + 86400,
    amr: [{ method: 'password', timestamp: agora }], session_id: 'demo', email: USER.email }) + '.ZGVtbw';
  var SESSAO = { access_token: JWT, token_type: 'bearer', expires_in: 86400, expires_at: agora + 86400, refresh_token: 'demo', user: USER };
  try { localStorage.setItem('sb-' + REF + '-auth-token', JSON.stringify(SESSAO)); } catch (e) {}

  // ── Dados fictícios (mes é 0-indexado: 8 = setembro) ──
  function semente() {
    var nomes = ['Dra. Ana Souza', 'Dr. Bruno Lima', 'Clínica Sorriso', 'Dra. Carla Mendes', 'Dr. Diego Rocha', 'Odonto Vida', 'Dra. Elisa Prado', 'Dr. Fábio Nunes'];
    var tels = ['(11) 98888-1234', '', '(21) 3333-4444', '11977776666', '', '(11) 96666-5555', '(14) 99704-0000', ''];
    var ext = 'https://' + HOST + '/storage/v1/object/public/extratos/';
    function cm(reg, mes, valor, pago, path, enviado) {
      return { id: 'cm' + reg + '-' + mes, cliente_reg: reg, mes: mes, ano: 2026, valor_mes: valor, valor_pago: pago, enviado: !!enviado,
        quitado: pago >= valor && valor > 0, extrato_path: path || null, extrato_url: path ? ext + path : null,
        created_at: '2026-09-01T10:00:00Z', updated_at: '2026-10-01T10:00:00Z', user_id: UID };
    }
    return {
      cadastro_clientes: nomes.map(function (n, i) { return { reg: i + 1, nome: n, tel: tels[i], status: 'ativo' }; }),
      controle_mensal: [cm(1, 7, 600, 0), cm(1, 8, 1850, 0), cm(2, 8, 2300, 1000), cm(3, 8, 640, 0), cm(4, 8, 920, 920),
        cm(5, 8, 480, 0, '2026_8/reg5_1.pdf'), cm(6, 8, 1320, 500), cm(7, 8, 760, 760, '2026_8/reg7_1.pdf', true)],
      saldo_abertura_clientes: [], apelidos_pagador: [], vencimento_mensal: [], fin_ia_uso: [],
      extratos_arquivos: [
        { id: 'e5', cliente_reg: 5, mes: 8, ano: 2026, path: '2026_8/reg5_1.pdf', hash_sha256: 'exemplo-diego-antigo', nome_arquivo: 'extrato_diego_antigo.pdf',
          divergente: false, decisao_divergencia: null, leitor: 'leitor', situacao: 'anexado', criado_em: '2026-09-30T10:00:00Z', lote_id: 'lote-0' },
        { id: 'e7', cliente_reg: 7, mes: 8, ano: 2026, path: '2026_8/reg7_1.pdf', nome_arquivo: 'extrato_elisa_set.pdf',
          hash_sha256: '5a3c5b7faa96c0e80a8ebfd734ef6d8051ca1b89a08abb6da9768659b5d05159',
          divergente: false, decisao_divergencia: null, leitor: 'leitor', situacao: 'anexado', criado_em: '2026-10-01T10:00:00Z', lote_id: 'lote-0' }],
      fin_envios: [{ id: 'env1', cliente_reg: 7, mes: 8, ano: 2026, tipo: 'extrato', criado_em: '2026-10-02T12:14:00Z', telefone: '5514997040000' }],
      pedidos: [{ id: 'p1', cliente_reg: 8, status: 'producao', valor: 0, created_at: '2026-09-15T12:00:00Z' }],
      fin_config: [{ user_id: UID, chave_pix: null, modelo_extrato: null, ia_modelo: 'claude-opus-5-5', ia_limite_diario_usd: 0, ia_max_leituras_dia: 200,
        email_resumo: 'contato.idealilab@gmail.com' }],
      fin_lotes: [{ id: 'lote-0', tipo: 'extratos', criado_em: '2026-10-01T10:00:00Z', desfeito_em: null, resumo: { qtd: 2 } }],
      fin_auditoria: [
        { id: 'a1', quando: '2026-10-02T12:14:05Z', usuario_email: 'demonstracao@exemplo.com', tabela: 'controle_mensal', acao: 'update',
          antes: { cliente_reg: 7, mes: 8, ano: 2026, enviado: false }, depois: { cliente_reg: 7, mes: 8, ano: 2026, enviado: true } },
        { id: 'a2', quando: '2026-10-01T13:00:02Z', usuario_email: 'demonstracao@exemplo.com', tabela: 'controle_mensal', acao: 'update',
          antes: { cliente_reg: 7, mes: 8, ano: 2026, extrato_path: null }, depois: { cliente_reg: 7, mes: 8, ano: 2026, extrato_path: '2026_8/reg7_1.pdf' } }]
    };
  }
  function ler() { try { var s = localStorage.getItem(CHAVE_DB); if (s) return JSON.parse(s); } catch (e) {} return semente(); }
  function gravar(db) { try { localStorage.setItem(CHAVE_DB, JSON.stringify(db)); } catch (e) {} }
  window.idealiDemoReiniciar = function () {
    try { localStorage.removeItem(CHAVE_DB); } catch (e) {}
    (window.top || window).location.reload();
  };

  var seq = 0;
  function novoId() { return 'demo-' + Date.now().toString(36) + '-' + (++seq); }
  function auditar(db, tabela, acao, antes, depois) {
    db.fin_auditoria.unshift({ id: novoId(), quando: new Date().toISOString(), usuario_email: USER.email, tabela: tabela, acao: acao, antes: antes, depois: depois });
  }

  // ── Filtros no formato do PostgREST (eq, neq, gt, gte, lt, lte, is, in) ──
  function comparar(a, op, b) {
    if (op === 'is') return b === 'null' ? a == null : String(a) === b;
    if (op === 'in') return b.replace(/^\(|\)$/g, '').split(',').map(function (x) { return x.replace(/^"|"$/g, ''); }).indexOf(String(a)) >= 0;
    if (op === 'eq') return String(a) === b;
    if (op === 'neq') return String(a) !== b;
    var x, y;
    if (typeof a === 'number') { x = a; y = Number(b); }
    else if (/^\d{4}-\d\d-\d\d/.test(String(a)) && /^\d{4}-\d\d-\d\d/.test(b)) { x = Date.parse(a); y = Date.parse(b); }
    else { x = String(a); y = b; }
    if (a == null) return false;
    return op === 'gt' ? x > y : op === 'gte' ? x >= y : op === 'lt' ? x < y : op === 'lte' ? x <= y : true;
  }
  var RESERVADOS = ['select', 'order', 'limit', 'offset', 'on_conflict', 'columns'];
  function filtrar(rows, q) {
    q.forEach(function (v, k) {
      if (RESERVADOS.indexOf(k) >= 0) return;
      var m = /^(not\.)?(eq|neq|gt|gte|lt|lte|is|in)\.(.*)$/.exec(v);
      if (!m) return;
      rows = rows.filter(function (r) { var ok = comparar(r[k], m[2], m[3]); return m[1] ? !ok : ok; });
    });
    return rows;
  }
  function ordenar(rows, q) {
    var o = q.get('order'); if (!o) return rows;
    var p = o.split(',')[0].split('.'), col = p[0], desc = p.indexOf('desc') > 0;
    return rows.slice().sort(function (a, b) {
      var x = a[col], y = b[col]; if (x === y) return 0; if (x == null) return 1; if (y == null) return -1;
      return (x < y ? -1 : 1) * (desc ? -1 : 1);
    });
  }

  function resposta(status, corpo, extra) {
    var h = Object.assign({ 'Content-Type': 'application/json' }, extra || {});
    return new Response(status === 204 || corpo === undefined ? null : JSON.stringify(corpo), { status: status, headers: h });
  }
  function erroPg(msg) { return resposta(400, { code: 'P0001', message: msg, details: null, hint: null }); }

  async function corpoJson(req) { try { var t = await req.clone().text(); return t ? JSON.parse(t) : null; } catch (e) { return null; } }

  // ── Tabelas ──
  async function tabela(req, nome, q) {
    var db = ler(); if (!db[nome]) db[nome] = [];
    var objeto = /vnd\.pgrst\.object/.test(req.headers.get('accept') || '');
    var prefer = req.headers.get('prefer') || '';
    var devolve = /return=representation/.test(prefer);
    var m = req.method;
    function saida(rows) {
      if (objeto) return rows.length === 1 ? resposta(200, rows[0]) : resposta(406, { code: 'PGRST116', message: 'JSON object requested, multiple (or no) rows returned' });
      return resposta(200, rows, { 'Content-Range': '0-' + Math.max(rows.length - 1, 0) + '/' + rows.length });
    }
    if (m === 'GET' || m === 'HEAD') {
      var rows = ordenar(filtrar(db[nome], q), q);
      var lim = parseInt(q.get('limit') || '0', 10); if (lim) rows = rows.slice(0, lim);
      return saida(rows);
    }
    if (m === 'POST') {
      var b = await corpoJson(req); var lista = Array.isArray(b) ? b : [b];
      var agoraIso = new Date().toISOString();
      var novos = lista.map(function (r) {
        var n = Object.assign({ id: novoId(), user_id: UID, created_at: agoraIso, criado_em: agoraIso, quando: agoraIso }, r);
        db[nome].unshift(n); auditar(db, nome, 'insert', null, r); return n;
      });
      gravar(db);
      return devolve ? saida(novos) : resposta(201, undefined);
    }
    if (m === 'PATCH') {
      var b2 = await corpoJson(req) || {};
      var alvo = filtrar(db[nome], q);
      alvo.forEach(function (r) { var antes = Object.assign({}, r); Object.assign(r, b2); auditar(db, nome, 'update', antes, Object.assign({}, r)); });
      gravar(db);
      return devolve ? saida(alvo) : resposta(204);
    }
    if (m === 'DELETE') {
      var apagar = filtrar(db[nome], q);
      db[nome] = db[nome].filter(function (r) { return apagar.indexOf(r) < 0; });
      apagar.forEach(function (r) { auditar(db, nome, 'delete', r, null); });
      gravar(db);
      return devolve ? saida(apagar) : resposta(204);
    }
    return resposta(405, { message: 'método não simulado' });
  }

  // ── Funções do banco (mesmas regras da 051) ──
  async function rpc(req, nome) {
    var b = await corpoJson(req) || {};
    var db = ler();
    if (nome === 'ideali_e_dono' || nome === 'ideali_aal_ok') return resposta(200, true);
    if (nome === 'ideali_papel') return resposta(200, 'dono');
    if (nome === 'fin_ia_consumir') return resposta(200, { ok: false, motivo: 'desligada' });
    if (nome === 'fin_anexar_extrato') {
      var p = b.p || {};
      var lote = db.fin_lotes.find(function (l) { return l.id === p.lote_id && !l.desfeito_em; });
      if (!lote) return erroPg('Lote de importacao invalido.');
      var dup = db.extratos_arquivos.find(function (e) { return e.hash_sha256 === p.hash_sha256 && e.situacao !== 'desfeito'; });
      if (dup) return erroPg('DUPLICADO_HASH: este PDF ja foi anexado (cliente ' + dup.cliente_reg + ', mes ' + (dup.mes + 1) + '/' + dup.ano + ').');
      var cm = db.controle_mensal.find(function (c) { return c.cliente_reg === p.cliente_reg && c.mes === p.mes && c.ano === p.ano; });
      if (cm && cm.extrato_path && !p.substituir) return erroPg('JA_TEM_EXTRATO: cliente ' + p.cliente_reg + ' ja tem extrato em ' + (p.mes + 1) + '/' + p.ano + '. Marque "substituir" para trocar.');
      var total = p.total_lido == null ? null : Number(p.total_lido);
      var div = total == null || Math.abs(total - (cm ? cm.valor_mes : 0)) > 0.004;
      if (div && !p.decisao_divergencia) return erroPg('DIVERGENCIA: total do extrato diferente do valor do mes no sistema. Escolha manter ou usar o do PDF.');
      var antes = cm ? { url: cm.extrato_url, path: cm.extrato_path, valor: cm.valor_mes } : { url: null, path: null, valor: null };
      var agoraIso = new Date().toISOString();
      if (!cm) {
        cm = { id: novoId(), cliente_reg: p.cliente_reg, mes: p.mes, ano: p.ano, valor_mes: p.decisao_divergencia === 'usar_pdf' ? total : 0, valor_pago: 0,
          enviado: false, quitado: false, created_at: agoraIso, user_id: UID };
        db.controle_mensal.push(cm);
      } else {
        db.extratos_arquivos.forEach(function (e) { if (e.cliente_reg === p.cliente_reg && e.mes === p.mes && e.ano === p.ano && e.situacao === 'anexado') e.situacao = 'substituido'; });
      }
      var cmAntes = Object.assign({}, cm);
      cm.extrato_url = p.url; cm.extrato_path = p.path; cm.updated_at = agoraIso;
      if (p.decisao_divergencia === 'usar_pdf') cm.valor_mes = total;
      auditar(db, 'controle_mensal', 'update', cmAntes, Object.assign({}, cm));
      var id = novoId();
      db.extratos_arquivos.unshift({ id: id, lote_id: p.lote_id, cliente_reg: p.cliente_reg, mes: p.mes, ano: p.ano, path: p.path, hash_sha256: p.hash_sha256,
        nome_arquivo: p.nome_arquivo, divergente: div, decisao_divergencia: div ? p.decisao_divergencia : null, leitor: p.leitor || 'leitor',
        situacao: 'anexado', criado_em: agoraIso, antes_extrato_url: antes.url, antes_extrato_path: antes.path, antes_valor_mes: antes.valor });
      if (p.apelido_norm) {
        var ap = db.apelidos_pagador.find(function (a) { return a.origem === 'extrato' && a.apelido_norm === p.apelido_norm; });
        if (ap) ap.cliente_reg = p.cliente_reg;
        else db.apelidos_pagador.push({ id: novoId(), origem: 'extrato', apelido_norm: p.apelido_norm, apelido: p.nome_lido || p.apelido_norm, cliente_reg: p.cliente_reg });
      }
      gravar(db);
      return resposta(200, { id: id, divergente: div });
    }
    if (nome === 'fin_desfazer_ultimo_lote') {
      var ult = db.fin_lotes.filter(function (l) { return !l.desfeito_em; }).sort(function (a, b) { return a.criado_em < b.criado_em ? 1 : -1; })[0];
      if (!ult) return erroPg('Nao ha importacao para desfazer.');
      var doLote = db.extratos_arquivos.filter(function (e) { return e.lote_id === ult.id && e.situacao !== 'desfeito'; });
      doLote.slice().reverse().forEach(function (e) {
        var c = db.controle_mensal.find(function (x) { return x.cliente_reg === e.cliente_reg && x.mes === e.mes && x.ano === e.ano; });
        if (c) {
          var a0 = Object.assign({}, c);
          c.extrato_url = e.antes_extrato_url || null; c.extrato_path = e.antes_extrato_path || null;
          c.valor_mes = e.antes_valor_mes == null ? 0 : e.antes_valor_mes; c.updated_at = new Date().toISOString();
          auditar(db, 'controle_mensal', 'update', a0, Object.assign({}, c));
        }
        db.extratos_arquivos.forEach(function (x) {
          if (x.cliente_reg === e.cliente_reg && x.mes === e.mes && x.ano === e.ano && x.situacao === 'substituido' && x.path === e.antes_extrato_path && x.lote_id !== ult.id) x.situacao = 'anexado';
        });
      });
      var paths = doLote.map(function (e) { return e.path; });
      db.extratos_arquivos.forEach(function (e) { if (e.lote_id === ult.id) e.situacao = 'desfeito'; });
      ult.desfeito_em = new Date().toISOString();
      gravar(db);
      return resposta(200, { lote_id: ult.id, paths: paths });
    }
    return resposta(200, null);
  }

  // ── Roteador: tudo que iria para o Supabase cai aqui ──
  async function simular(req) {
    var u = new URL(req.url), caminho = u.pathname;
    if (caminho.indexOf('/auth/v1/') === 0) {
      if (/\/user$/.test(caminho)) return resposta(200, USER);
      if (/\/token$/.test(caminho)) return resposta(200, SESSAO);
      if (/\/logout$/.test(caminho)) return resposta(204);
      return resposta(200, {});
    }
    if (caminho.indexOf('/rest/v1/rpc/') === 0) return rpc(req, caminho.split('/').pop());
    if (caminho.indexOf('/rest/v1/') === 0) return tabela(req, caminho.split('/')[3], u.searchParams);
    if (caminho.indexOf('/functions/v1/') === 0)
      return resposta(429, { erro: 'IA desligada (modo demonstração). Preencha à mão.', limite: true });
    if (caminho.indexOf('/storage/v1/object/sign/') === 0) {
      var arq = caminho.replace('/storage/v1/object/sign/', '');
      return resposta(200, { signedURL: '/object/sign/' + arq + '?token=DEMONSTRACAO' });
    }
    if (caminho.indexOf('/storage/v1/object/') === 0) {
      if (req.method === 'POST' || req.method === 'PUT') return resposta(200, { Key: caminho.replace('/storage/v1/object/', ''), Id: novoId() });
      return resposta(200, []);
    }
    return resposta(200, []);
  }

  var fetchOriginal = window.fetch.bind(window);
  window.fetch = function (entrada, opcoes) {
    var req = new Request(entrada, opcoes);
    if (new URL(req.url, location.href).host === HOST) {
      return simular(req).catch(function (e) { return resposta(500, { message: 'Demonstração: ' + (e && e.message) }); });
    }
    return fetchOriginal(entrada, opcoes);
  };

  // ── Aviso visível (só na janela principal; a Central abre dentro dela) ──
  if (window.top !== window) return;
  function aviso() {
    if (document.getElementById('demo-aviso')) return;
    var css = document.createElement('style');
    css.textContent =
      '#demo-moldura{position:fixed;inset:0;border:5px solid #E8590C;pointer-events:none;z-index:2147483646}' +
      '#demo-aviso{position:fixed;left:50%;bottom:14px;transform:translateX(-50%);z-index:2147483647;display:flex;align-items:center;gap:10px;' +
      'background:#E8590C;color:#fff;font:700 14px/1.2 system-ui,"Segoe UI",sans-serif;padding:9px 10px 9px 16px;border-radius:999px;' +
      'box-shadow:0 8px 24px -8px rgba(0,0,0,.5);max-width:calc(100vw - 32px)}' +
      '#demo-aviso span{white-space:normal}' +
      '#demo-aviso button{background:#fff;color:#B8430A;border:0;border-radius:999px;padding:6px 12px;font:700 13px system-ui,sans-serif;cursor:pointer;flex-shrink:0}' +
      '@media (max-width:640px){#demo-aviso{bottom:auto;top:8px;font-size:12px}}';
    document.head.appendChild(css);
    var moldura = document.createElement('div'); moldura.id = 'demo-moldura';
    var caixa = document.createElement('div'); caixa.id = 'demo-aviso'; caixa.setAttribute('role', 'status');
    caixa.innerHTML = '<span>⚠ MODO DEMONSTRAÇÃO · dados fictícios · nada vai para o banco real</span>' +
      '<button type="button" onclick="idealiDemoReiniciar()">Recomeçar</button>';
    document.body.appendChild(moldura); document.body.appendChild(caixa);
    document.title = '[DEMONSTRAÇÃO] ' + document.title;
  }
  if (document.body) aviso(); else document.addEventListener('DOMContentLoaded', aviso);
})();
