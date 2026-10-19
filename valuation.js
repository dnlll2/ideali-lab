/* ================================================================
   valuation.js — "Quanto o laboratório vale hoje" (estimativa)
   Mesmo método do Ideali CAD, adaptado para o laboratório:
     Valuation = Receita anual × Múltiplo
   Receita anual = pedidos recebidos nos últimos 365 dias (com menos de
   1 ano de histórico: projeta para 12 meses). O múltiplo começa em 1,0x,
   cada fator soma ou subtrai, e fica entre 0,3x e 2,0x.

   Só para o dono e a Inove (o banco também só entrega pedidos/valores a
   eles). Tudo é calculado aqui no aparelho: nada vai para fora, sem IA.
   O valor de cada mês (até 24) fica nas preferências do próprio login
   (user_metadata.valuation_hist) para mostrar a seta contra o mês passado.
   ================================================================ */
(function () {
  var DIA = 86400000;
  var STATUS_FORA = ['orcamento', 'cancelado'];   // orçamento e cancelado não são pedido recebido

  function limitar(v, a, b) { return Math.max(a, Math.min(b, v)); }
  function pct(v) { return (v * 100).toLocaleString('pt-BR', { maximumFractionDigits: 1 }) + '%'; }
  function mult(v) { return v.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + 'x'; }
  function ajusteTxt(v) { return (v > 0 ? '+' : v < 0 ? '−' : '') + mult(Math.abs(v)); }
  function brl(v) { return 'R$ ' + Number(v || 0).toLocaleString('pt-BR', { minimumFractionDigits: 0, maximumFractionDigits: 0 }); }
  function brlCurto(v) {
    v = Number(v || 0);
    if (v >= 1e6) return 'R$ ' + (v / 1e6).toLocaleString('pt-BR', { maximumFractionDigits: 1 }) + ' mi';
    if (v >= 1000) return 'R$ ' + (v / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 1 }) + ' mil';
    return brl(v);
  }
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function chaveMes(d) { return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0'); }

  // ── O cálculo (puro: recebe os dados e a data de referência) ──
  // pedidos: [{valor, cliente_reg, status, created_at}]
  // controle: [{cliente_reg, mes (0-11), ano, valor_mes, valor_pago, quitado}]
  function calcular(pedidos, controle, hoje) {
    hoje = hoje || new Date();
    var t = hoje.getTime();
    var validos = (pedidos || []).filter(function (p) {
      return STATUS_FORA.indexOf(p.status) < 0 && p.created_at && new Date(p.created_at).getTime() <= t;
    }).map(function (p) { return { v: Number(p.valor) || 0, c: p.cliente_reg, t: new Date(p.created_at).getTime() }; });

    var r = { valor: 0, receita: 0, projetada: false, multiplo: 1, fatores: [], dicas: [], novo: false, dias: 0 };
    if (!validos.length) { r.novo = true; return r; }

    var primeiro = Math.min.apply(null, validos.map(function (p) { return p.t; }));
    var dias = Math.max(1, Math.floor((t - primeiro) / DIA));
    r.dias = dias;
    function soma(de, ate) { return validos.reduce(function (s, p) { return p.t > t - de * DIA && p.t <= t - ate * DIA ? s + p.v : s; }, 0); }
    var r365 = soma(365, 0);
    if (dias < 365) { r.receita = r365 / Math.max(dias, 90) * 365; r.projetada = true; }
    else r.receita = r365;

    // 1. Crescimento: últimos 90 dias contra os 90 anteriores
    var r90 = soma(90, 0), r90a = soma(180, 90);
    if (dias < 180 || (r90a === 0 && r90 > 0)) {
      if (r90 > 0) r.fatores.push({ id: 'crescimento', nome: 'Crescimento', aj: 0.05,
        frase: 'O laboratório começou a faturar há pouco tempo no sistema: ainda não dá para comparar trimestres.' });
    } else if (r90a > 0) {
      var vr = (r90 - r90a) / r90a;
      r.fatores.push({ id: 'crescimento', nome: 'Crescimento', aj: limitar(vr * 0.3, -0.3, 0.3),
        frase: 'Receita dos últimos 90 dias ' + (vr >= 0 ? 'cresceu ' : 'caiu ') + pct(Math.abs(vr)) + ' contra os 90 dias anteriores.' });
    }

    // 2. Concentração: quanto da receita de 12 meses vem do maior cliente
    if (r365 > 0) {
      var porCli = {};
      validos.forEach(function (p) { if (p.t > t - 365 * DIA) porCli[p.c] = (porCli[p.c] || 0) + p.v; });
      var maior = Math.max.apply(null, Object.keys(porCli).map(function (k) { return porCli[k]; }));
      var c = maior / r365;
      r.fatores.push({ id: 'concentracao', nome: 'Concentração', aj: c > 0.5 ? -0.25 : c > 0.3 ? -0.10 : 0.05,
        frase: 'O maior cliente responde por ' + pct(c) + ' da receita dos últimos 12 meses' + (c > 0.3 ? ': depender de um só é risco.' : '.') });
    }

    // 3. Carteira ativa: clientes que mandaram trabalho nos últimos 90 dias
    var ativos = {};
    validos.forEach(function (p) { if (p.t > t - 90 * DIA) ativos[p.c] = 1; });
    var na = Object.keys(ativos).length;
    r.fatores.push({ id: 'carteira', nome: 'Carteira ativa', aj: na >= 10 ? 0.15 : na >= 5 ? 0.08 : na >= 3 ? 0 : -0.10,
      frase: na + (na === 1 ? ' cliente mandou' : ' clientes mandaram') + ' trabalho nos últimos 90 dias.' });

    // 4 e 5. Prazo e Retrabalho: o banco ainda não tem "entregue em" nem "refação" → não entram
    r.fatores.push({ id: 'prazo', nome: 'Prazo', aj: null,
      frase: 'Sem dados ainda: entra quando a Produção registrar o prazo e a data de entrega de cada pedido.' });
    r.fatores.push({ id: 'retrabalho', nome: 'Retrabalho/refação', aj: null,
      frase: 'Sem dados ainda: entra quando a Produção registrar refações e ajustes.' });

    // 6. Inadimplência: valor do mês não pago, de meses fechados há mais de 30 dias
    var comValor = (controle || []).filter(function (x) { return Number(x.valor_mes) > 0; });
    if (comValor.length && r.receita > 0) {
      var corte = t - 30 * DIA, aberto = 0;
      comValor.forEach(function (x) {
        var fim = new Date(x.ano, x.mes + 1, 0, 23, 59, 59).getTime();   // mes do banco é 0-indexado
        if (fim <= corte && !x.quitado) aberto += Math.max(0, Number(x.valor_mes) - Number(x.valor_pago || 0));
      });
      var ip = aberto / r.receita;
      r.fatores.push({ id: 'inadimplencia', nome: 'Inadimplência', aj: ip > 0.10 ? -0.15 : ip >= 0.03 ? -0.05 : 0.03,
        frase: brl(aberto) + ' em aberto há mais de 30 dias (' + pct(ip) + ' da receita anual).' });
    }

    // 7. Tempo de casa (desde o primeiro pedido no sistema)
    var meses = dias / 30.4;
    r.fatores.push({ id: 'tempo', nome: 'Tempo de casa', aj: meses < 6 ? -0.20 : meses < 12 ? -0.10 : meses >= 24 ? 0.10 : 0,
      frase: 'Histórico de ' + (meses < 1 ? dias + ' dias' : Math.floor(meses) + (Math.floor(meses) === 1 ? ' mês' : ' meses')) + ' de pedidos no sistema.' });

    var somaAj = r.fatores.reduce(function (s, f) { return f.aj == null ? s : s + f.aj; }, 0);
    r.multiplo = limitar(1 + somaAj, 0.3, 2.0);
    r.valor = Math.round(r.receita * r.multiplo / 100) * 100;
    r.dicas = r.fatores.filter(function (f) { return f.aj != null && f.aj < 0; })
      .sort(function (a, b) { return a.aj - b.aj; }).slice(0, 3)
      .map(function (f) { return DICAS[f.id]; });
    return r;
  }
  var DICAS = {
    prazo: 'Priorize os atrasados: prazo cumprido é o que mais valoriza o laboratório.',
    retrabalho: 'Confira antes de entregar: menos refação é mais lucro e mais confiança.',
    crescimento: 'Procure os clientes que diminuíram os pedidos: voltar a crescer trimestre a trimestre valoriza o laboratório.',
    concentracao: 'Traga novos dentistas: depender menos do maior cliente reduz o risco do negócio.',
    carteira: 'Reative clientes parados: mais clientes mandando trabalho todo trimestre aumenta o valor.',
    inadimplencia: 'Cobre o que está em aberto há mais de 30 dias: dinheiro parado na rua reduz o valor.',
    tempo: 'O tempo de casa melhora sozinho: continue registrando todos os pedidos no sistema.'
  };

  // ── Dados do banco (só dono e Inove recebem; RLS garante no servidor) ──
  async function todos(sb, tabela, cols) {
    var out = [], de = 0, passo = 1000;
    for (;;) {
      var r = await sb.from(tabela).select(cols).range(de, de + passo - 1);
      if (r.error) throw r.error;
      out = out.concat(r.data || []);
      if (!r.data || r.data.length < passo) return out;
      de += passo;
    }
  }
  function papelPermitido() {
    var p = typeof idealiPapel === 'function' ? idealiPapel() : '';
    return p === 'dono' || p === 'inove';
  }

  // ── Histórico mensal no próprio login ──
  async function historico(sb, atual, dados) {
    var u = (await sb.auth.getUser()).data.user;
    var h = Object.assign({}, (u && u.user_metadata && u.user_metadata.valuation_hist) || {});
    var hoje = new Date(), kAtual = chaveMes(hoje);
    var fimPassado = new Date(hoje.getFullYear(), hoje.getMonth(), 0, 23, 59, 59);
    var kPassado = chaveMes(fimPassado), mudou = false;
    // Primeira vez: o mês passado é calculado com os pedidos até o último dia dele
    if (h[kPassado] == null && !atual.novo) { h[kPassado] = calcular(dados.pedidos, dados.controle, fimPassado).valor; mudou = true; }
    if (h[kAtual] !== atual.valor) { h[kAtual] = atual.valor; mudou = true; }
    var ks = Object.keys(h).sort();
    while (ks.length > 24) { delete h[ks.shift()]; mudou = true; }
    if (mudou) sb.auth.updateUser({ data: { valuation_hist: h } }).catch(function () {});
    return { passado: h[kPassado], hist: h };
  }

  var ESTADO = null;
  async function carregar(sb) {
    if (!papelPermitido()) return null;
    var dados = { pedidos: await todos(sb, 'pedidos', 'valor,cliente_reg,status,created_at'),
                  controle: await todos(sb, 'controle_mensal', 'cliente_reg,mes,ano,valor_mes,valor_pago,quitado') };
    var r = calcular(dados.pedidos, dados.controle, new Date());
    var h = await historico(sb, r, dados);
    r.passado = h.passado;
    r.variacao = h.passado > 0 ? (r.valor - h.passado) / h.passado : null;
    ESTADO = r;
    return r;
  }

  // ── Tela ──
  function setaHtml(r) {
    if (r.variacao == null) return '';
    var sobe = r.variacao >= 0;
    return '<span class="vl-var ' + (sobe ? 'sobe' : 'desce') + '"><span aria-hidden="true">' + (sobe ? '▲' : '▼') + '</span>' +
      '<span class="vl-sr">' + (sobe ? 'subiu ' : 'caiu ') + '</span>' + pct(Math.abs(r.variacao)) + '</span>';
  }
  function chipHtml(r) {
    return '<i class="ti ti-trending-up" aria-hidden="true"></i><span>Valuation <b>' + brlCurto(r.valor) + '</b></span>' + setaHtml(r);
  }
  function janelaHtml(r) {
    var fat = r.fatores.map(function (f) {
      var cls = f.aj == null ? 'nd' : f.aj > 0 ? 'pos' : f.aj < 0 ? 'neg' : 'zero';
      return '<li><div class="vl-ft"><b>' + esc(f.nome) + '</b><span class="vl-aj ' + cls + '">' + (f.aj == null ? 'sem dados' : ajusteTxt(f.aj)) + '</span></div>' +
        '<p>' + esc(f.frase) + '</p></li>';
    }).join('');
    var dicas = r.dicas.length ? '<h3>Como aumentar</h3><ul class="vl-dicas">' + r.dicas.map(function (d) { return '<li><i class="ti ti-bulb" aria-hidden="true"></i><span>' + esc(d) + '</span></li>'; }).join('') + '</ul>' : '';
    var conta = r.novo
      ? '<p class="vl-novo">Ainda não há pedidos registrados. Toda conta começa valendo R$ 0 e sobe conforme registra pedidos.</p>'
      : '<div class="vl-conta" aria-label="Conta do valuation">' +
          '<div><small>Receita anual' + (r.projetada ? ' (projetada)' : '') + '</small><b>' + brl(r.receita) + '</b></div><span aria-hidden="true">×</span>' +
          '<div><small>Múltiplo</small><b>' + mult(r.multiplo) + '</b></div><span aria-hidden="true">=</span>' +
          '<div><small>Valuation</small><b>' + brl(r.valor) + '</b></div></div>';
    var passado = r.passado != null ? '<p class="vl-passado">Mês passado: ' + brl(r.passado) + ' ' + setaHtml(r) + '</p>' : '';
    return '<div class="vl-cab"><span class="vl-tag"><i class="ti ti-trending-up" aria-hidden="true"></i> Valuation</span>' +
        '<button type="button" class="vl-x" data-vl-fechar aria-label="Fechar"><i class="ti ti-x"></i></button></div>' +
      '<p class="vl-rot">Seu laboratório vale hoje</p>' +
      '<p class="vl-grande">' + brl(r.valor) + '</p>' + passado + conta +
      (r.novo ? '' : '<h3>Fatores</h3><ul class="vl-fatores">' + fat + '</ul>') + dicas +
      '<div class="vl-metodo"><h3>Como é calculado</h3>' +
        '<p>Valuation = Receita anual × Múltiplo. A receita anual é a soma dos pedidos recebidos nos últimos 365 dias' +
        ' (sem orçamentos e cancelados). Com menos de 1 ano de histórico, ela é projetada para 12 meses.' +
        ' O múltiplo começa em 1,0x, cada fator soma ou subtrai, e fica entre 0,3x e 2,0x. O resultado é arredondado para a centena.' +
        ' Fator sem dados não entra na conta.</p>' +
        '<p><b>É uma estimativa</b> para acompanhar a evolução do negócio mês a mês, não uma avaliação oficial.' +
        ' É calculada no seu aparelho com os dados do laboratório, sem enviar nada para fora.</p></div>';
  }
  var _anterior = null;
  function abrir() {
    if (!ESTADO) return;
    var ov = document.getElementById('vl-ov');
    if (!ov) {
      ov = document.createElement('div');
      ov.id = 'vl-ov'; ov.className = 'vl-ov';
      ov.innerHTML = '<div class="vl-janela" role="dialog" aria-modal="true" aria-label="Valuation do laboratório" tabindex="-1"></div>';
      ov.addEventListener('click', function (e) { if (e.target === ov || e.target.closest('[data-vl-fechar]')) fechar(); });
      document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && !ov.hidden) fechar(); });
      document.body.appendChild(ov);
    }
    _anterior = document.activeElement;
    ov.firstChild.innerHTML = janelaHtml(ESTADO);
    // Tela antiga mais larga que o celular: a janela acompanha só a parte visível
    var vv = window.visualViewport;
    if (vv && vv.width < window.innerWidth - 1) {
      ov.style.left = vv.offsetLeft + 'px'; ov.style.top = vv.offsetTop + 'px';
      ov.style.width = vv.width + 'px'; ov.style.height = vv.height + 'px'; ov.style.right = ov.style.bottom = 'auto';
    } else ov.removeAttribute('style');
    ov.hidden = false;
    document.documentElement.classList.add('vl-aberto');
    ov.firstChild.focus();
  }
  function fechar() {
    var ov = document.getElementById('vl-ov'); if (!ov) return;
    ov.hidden = true;
    document.documentElement.classList.remove('vl-aberto');
    if (_anterior && _anterior.focus) _anterior.focus();
  }
  // Liga os chips (qualquer elemento com data-vl-chip) ao valor calculado
  async function montar(sb) {
    var chips = document.querySelectorAll('[data-vl-chip]');
    if (!papelPermitido()) { chips.forEach(function (c) { c.hidden = true; }); return null; }
    var r = await carregar(sb);
    pintar();
    return r;
  }
  function pintar() {
    if (!ESTADO) return;
    document.querySelectorAll('[data-vl-chip]').forEach(function (c) {
      c.innerHTML = chipHtml(ESTADO);
      c.title = 'Valuation: estimativa de quanto o laboratório vale hoje';
      c.hidden = false;
      if (!c._vl) { c._vl = 1; c.addEventListener('click', abrir); }
    });
  }

  window.IdealiValuation = { calcular: calcular, carregar: carregar, montar: montar, pintar: pintar, abrir: abrir, fechar: fechar,
    permitido: papelPermitido, estado: function () { return ESTADO; } };
})();
