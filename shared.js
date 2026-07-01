/* ================================================================
   shared.js — Código compartilhado entre todas as páginas
   Ideali Laboratório
   ================================================================ */

// ── Supabase ──────────────────────────────────────────────────
var SUPABASE_URL = 'https://alqhhgysvehtgkwsxeok.supabase.co';
var SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFscWhoZ3lzdmVodGdrd3N4ZW9rIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MDE0ODg2NSwiZXhwIjoyMDk1NzI0ODY1fQ.xogvgvFob-7Ir6hSLkz0pOj3GawRPRbwfz9oGuGQ90E';
var sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// ── Constantes ────────────────────────────────────────────────
var MESES = ['Janeiro','Fevereiro','Marco','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
var COMISSAO = 0.17;

// ── Clientes (array hardcoded) ────────────────────────────────
var clients = [
  {reg:20,nome:"Adriana Tavares de Almeida",   cpf:"146.607.018-83",  cro:"CRO-SP 92640", end:"Rua Dezesseis de Dezembro, 10 - Sala 3",          bairro:"Jd. Rubio",          cidade:"Sao Paulo",           uf:"SP", cep:"",          tel:"",                  obs:""},
  {reg:23,nome:"Alexandre Miranda Souza",      cpf:"364.962.048-59",  cro:"",             end:"Av. Brasil, 1336 - 1 Andar",                      bairro:"",                   cidade:"Ferraz de Vasconcelos",uf:"SP",cep:"",          tel:"(11) 97723-2657",   obs:""},
  {reg:3, nome:"Anthony Borges",               cpf:"378.641.768-79",  cro:"126.653",      end:"Av. Silvestre Pires de Freitas, 800",             bairro:"Jardim Paraiso",     cidade:"Guarulhos",           uf:"SP", cep:"07144-000", tel:"",                  obs:"Costa Borges Odontologia"},
  {reg:7, nome:"Bruno Rocco Giusto",           cpf:"300.066.978-79",  cro:"",             end:"Av. Agua Fria, 1896",                             bairro:"Agua Fria",          cidade:"Sao Paulo",           uf:"SP", cep:"02332-001", tel:"",                  obs:"Entregar via motoboy (Katia)"},
  {reg:10,nome:"Caio Vinicius Barreto dos Santos",cpf:"376.257.418-93",cro:"",            end:"Av. Inconfidencia Mineira, 1241",                 bairro:"Vila Antonieta",     cidade:"Sao Paulo",           uf:"SP", cep:"",          tel:"(11) 98216-2905",   obs:"Lab Barreto"},
  {reg:9, nome:"Danilo Tuttis T. G. dos Santos",cpf:"338.114.288-70", cro:"",             end:"Rua Prado Rochi, 145",                           bairro:"Vila Assis",         cidade:"Jau",                 uf:"SP", cep:"17210-270", tel:"(14) 99749-3400",   obs:""},
  {reg:4, nome:"Dr. Andre Ricardo G. Da Silva",cpf:"169.303.098-50",  cro:"SP 56824",     end:"Rua da Fonte, 199 - Sala 04",                    bairro:"Jardim Oriental",    cidade:"Osasco",              uf:"SP", cep:"",          tel:"(11) 3609-2030",    obs:"dr.andrericardo@gmail.com"},
  {reg:11,nome:"Dr. Renato Oliveira Ferreira da Silva",cpf:"261.834.798-61",cro:"",       end:"Rua Guilherme de Almeida, 2-31",                  bairro:"Vila Cidade Universitaria",cidade:"Bauru",         uf:"SP", cep:"17012-500", tel:"",                  obs:"Padrao"},
  {reg:8, nome:"Fernando 021 Dental Barra",    cpf:"CNPJ: 37.568.571/0001-37", cro:"",    end:"Av. das Americas, 3665 - Loja 214",              bairro:"Barra da Tijuca",    cidade:"Rio de Janeiro",      uf:"RJ", cep:"22631-000", tel:"",                  obs:"Padrao"},
  {reg:22,nome:"Gilberto Ferreira Esquivel",   cpf:"CNPJ: 13.265.402/0001-60",cro:"CRO-BA 7329",end:"Rua Henqueque Alves, 315",                bairro:"Castalia",           cidade:"Itabuna",             uf:"BA", cep:"",          tel:"",                  obs:""},
  {reg:18,nome:"Henrique Falcao",              cpf:"029.583.461-70",  cro:"CRO 5045",     end:"Rua Sao Francisco Xavier, 168",                   bairro:"Tijuca",             cidade:"Rio de Janeiro",      uf:"RJ", cep:"",          tel:"",                  obs:"Clinica Odonto Premier"},
  {reg:5, nome:"Javier Garrido",               cpf:"CNPJ: 48.257.718/0001-94", cro:"75033", end:"Av. Conselheiro Rodrigues Alves, 518",         bairro:"Vila Mariana",       cidade:"Sao Paulo",           uf:"SP", cep:"04014-001", tel:"+55 (11) 98611-2003",obs:"Padrao"},
  {reg:24,nome:"Jose Ricardo de Miranda Pires",cpf:"013.432.346-70",  cro:"CRO-BA 8586",  end:"Rua Manuel Vilaboim, 121",                        bairro:"Centro",             cidade:"Cruz das Almas",      uf:"BA", cep:"44380-000", tel:"",                  obs:""},
  {reg:15,nome:"Julia Ando",                   cpf:"080.218.698-01",  cro:"CRO-SP TPD 9449",end:"Rua Santa Catarina, 240 - 5 andar, Sala 504", bairro:"Galeria Metropole",  cidade:"Sao Paulo",           uf:"SP", cep:"",          tel:"(11) 96387-3845",   obs:""},
  {reg:21,nome:"Juliano Balseiro",             cpf:"195.269.398-59",  cro:"CRO 65000",    end:"Av. Onze de Junho, 1199",                         bairro:"",                   cidade:"Sao Paulo",           uf:"SP", cep:"04041-054", tel:"",                  obs:""},
  {reg:2, nome:"Leonardo Moll",                cpf:"087.058.557-64",  cro:"RJ 36.484",    end:"Av. Ernani do Amaral Peixoto, 455 - Sala 711",   bairro:"Centro",             cidade:"Niteroi",             uf:"RJ", cep:"",          tel:"(21) 99541-9481",   obs:""},
  {reg:16,nome:"Luiz Junior",                  cpf:"127.496.107-61",  cro:"",             end:"Rua Academico Walter Goncalves, 1 - Sala 404",    bairro:"Centro",             cidade:"Niteroi",             uf:"RJ", cep:"24020-290", tel:"",                  obs:"Padrao"},
  {reg:12,nome:"Luiz Tolentino",               cpf:"",                cro:"",             end:"Rua Prefeito Jose Guilherme, 15",                 bairro:"Centro",             cidade:"Capela do Alto",      uf:"SP", cep:"18195-036", tel:"",                  obs:""},
  {reg:19,nome:"Pedro Henrique de Araujo Cruz",cpf:"446.153.318-27",  cro:"162.968",      end:"Av. Antonio Sylvio Cunha Bueno, 597",             bairro:"Jardim Inamar",      cidade:"Diadema",             uf:"SP", cep:"",          tel:"",                  obs:""},
  {reg:6, nome:"Renan Gerhard",                cpf:"133.262.117-16",  cro:"",             end:"Av. Geremario Dantas, 832 - Sala 207",            bairro:"Pechincha",          cidade:"Rio de Janeiro",      uf:"RJ", cep:"22743-010", tel:"",                  obs:""},
  {reg:1, nome:"Ricardo Cader",                cpf:"013.436.277-29",  cro:"",             end:"Av. Nossa Senhora de Copacabana, 749 - Sala 409", bairro:"Copacabana",         cidade:"Rio de Janeiro",      uf:"RJ", cep:"22050-002", tel:"",                  obs:""},
  {reg:13,nome:"Rodrigo Guimaraes",            cpf:"006.571.367-27",  cro:"",             end:"Av. Dr. Mario Guimaraes, 428 - Sala 813",         bairro:"Centro",             cidade:"Nova Iguacu",         uf:"RJ", cep:"26255-230", tel:"",                  obs:""},
  {reg:17,nome:"Talia Estefanelli Sampaio (Dr. Alfeu)",    cpf:"223.215.228-60",  cro:"CRO-SP 98329", end:"Rua Salem Bechara, 140 - Sala 1504",              bairro:"Centro",             cidade:"Osasco",              uf:"SP", cep:"",          tel:"",                  obs:"Dr. Alfeu"},
  {reg:25,nome:"Tiago Muller Pereira",         cpf:"025.981.860-79",  cro:"",             end:"Av. Salgado Filho, 2839",                         bairro:"",                   cidade:"Caxias do Sul",       uf:"RS", cep:"",          tel:"",                  obs:""},
  {reg:26,nome:"Raquel Ghesso Brentzel",        cpf:"435.301.458-74",  cro:"119391",       end:"Rua Ibitirama, 166 - Cj 902 Torre Office", bairro:"Vila Prudente",      cidade:"Sao Paulo",           uf:"SP", cep:"03134-000", tel:"",                  obs:""},
  {reg:27,nome:"Kleber Luander",              cpf:"144.031.517-52",  cro:"CRO-RJ 43164", end:"Av. Rotary, 947",                                bairro:"Centro",             cidade:"Sao Joao da Barra",   uf:"RJ", cep:"28200-000", tel:"",                  obs:"Lente Novo"},
  {reg:28,nome:"Luiz Carlos Figueiredo Seixas",cpf:"107.126.347-11",cro:"CRO-RJ 35796", end:"Rua Conde de Bonfim, 255 - Sala 810",            bairro:"Tijuca",             cidade:"Rio de Janeiro",      uf:"RJ", cep:"20520-051", tel:"",                  obs:""},
  {reg:29,nome:"Paulo Pagano",               cpf:"",                cro:"",             end:"Rua Salvador Bicudo, 109",                        bairro:"Tucuruvi",           cidade:"Sao Paulo",           uf:"SP", cep:"",          tel:"",                  email:"paulopagano0@gmail.com", obs:""},
  {reg:30,nome:"Juliana Barros",             cpf:"",                cro:"",             end:"",                                                bairro:"",                   cidade:"",                    uf:"",   cep:"",          tel:"",                  obs:""},
  {reg:31,nome:"Pedro Silva",                cpf:"",                cro:"",             end:"",                                                bairro:"",                   cidade:"",                    uf:"",   cep:"",          tel:"",                  obs:""},
  {reg:32,nome:"Carlos Vinicios Camelo",     cpf:"",                cro:"",             end:"",                                                bairro:"",                   cidade:"",                    uf:"",   cep:"",          tel:"",                  obs:""},
  {reg:33,nome:"Clinica Dr Rosmar",          cpf:"",                cro:"",             end:"",                                                bairro:"",                   cidade:"Rio de Janeiro",      uf:"RJ", cep:"",          tel:"",                  obs:""},
  {reg:34,nome:"Roberto Isao",               cpf:"",                cro:"",             end:"",                                                bairro:"",                   cidade:"",                    uf:"",   cep:"",          tel:"",                  obs:""},
  {reg:35,nome:"Rafael Heino Santos",        cpf:"",                cro:"",             end:"",                                                bairro:"",                   cidade:"",                    uf:"",   cep:"",          tel:"",                  obs:""},
  {reg:36,nome:"Oral 360 Copa",              cpf:"",                cro:"",             end:"R. Figueiredo de Magalhães, 226 - 201",           bairro:"Copacabana",         cidade:"Rio de Janeiro",      uf:"RJ", cep:"22031-012", tel:"",                  obs:""}
];

// ── Estado global ─────────────────────────────────────────────
var now = new Date();
var currentMonth = now.getMonth();
var currentYear  = now.getFullYear();
var viewMonth    = parseInt(localStorage.getItem('ideali-viewMonth') ?? currentMonth, 10);
var viewYear     = parseInt(localStorage.getItem('ideali-viewYear')  ?? currentYear,  10);
if (isNaN(viewMonth)) viewMonth = currentMonth;
if (isNaN(viewYear))  viewYear  = currentYear;

var avatarColors = [
  ['#1d3a6e','#93c5fd'],['#0d3d2b','#4ade80'],['#2e1d6e','#c4b5fd'],
  ['#3d1d1d','#fca5a5'],['#3d2e1d','#fcd34d'],['#1d3d2b','#6ee7b7']
];

// ── Utilitárias ───────────────────────────────────────────────
function initials(n) {
  var p = n.replace(/^(Dr\.|Dra\.)\s*/i,'').trim().split(' ');
  return (p[0][0] + (p[1] ? p[1][0] : '')).toUpperCase();
}

function fmt(v) {
  return 'R$ ' + Number(v||0).toLocaleString('pt-BR',{minimumFractionDigits:2,maximumFractionDigits:2});
}

function setSyncStatus(status) {
  var cls = 'sync-dot' + (status==='syncing' ? ' syncing' : status==='error' ? ' error' : '');
  var lbl = status==='syncing' ? 'Salvando...' : status==='error' ? 'Erro de conexao' : 'Conectado';
  var dot = document.getElementById('sync-dot');
  if (dot) dot.className = cls;
  var txt = document.getElementById('sync-status');
  if (txt) txt.innerHTML = '<span class="' + cls + '"></span>' + lbl;
}

function todayISO() {
  return new Date().toISOString().split('T')[0];
}

function todayLabel() {
  var d = new Date();
  var dias = ['domingo','segunda-feira','terca-feira','quarta-feira','quinta-feira','sexta-feira','sabado'];
  return dias[d.getDay()] + ', ' + d.getDate() + ' de ' + MESES[d.getMonth()].toLowerCase() + ' de ' + d.getFullYear();
}

function escHtml(s) {
  return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function fmtDate(iso) {
  if (!iso) return '';
  var p = iso.split('-');
  return p[2]+'/'+p[1]+'/'+p[0];
}

function fmtCreatedAt(iso) {
  if (!iso) return '—';
  if (/^\d{4}-\d{2}-\d{2}$/.test(iso)) {
    var p = iso.split('-');
    return p[2]+'/'+p[1]+'/'+p[0];
  }
  return new Date(iso).toLocaleString('pt-BR', {
    timeZone: 'America/Sao_Paulo',
    day:'2-digit', month:'2-digit', year:'numeric',
    hour:'2-digit', minute:'2-digit'
  });
}

function addWorkdays(dateIso, days) {
  var d = /^\d{4}-\d{2}-\d{2}$/.test(dateIso)
    ? new Date(dateIso + 'T12:00:00')
    : new Date(dateIso);
  var added = 0;
  while (added < days) {
    d.setDate(d.getDate() + 1);
    var dow = d.getDay();
    if (dow !== 0 && dow !== 6) added++;
  }
  return d.toLocaleDateString('pt-BR', {timeZone:'America/Sao_Paulo', day:'2-digit', month:'2-digit', year:'numeric'});
}

function valorPorExtenso(v) {
  if (!v || v <= 0) return 'zero reais';
  var cts = Math.round(v * 100);
  var reais = Math.floor(cts / 100);
  var cent  = cts % 100;
  var uns = ['','um','dois','tres','quatro','cinco','seis','sete','oito','nove',
             'dez','onze','doze','treze','quatorze','quinze','dezesseis','dezessete','dezoito','dezenove'];
  var dez = ['','','vinte','trinta','quarenta','cinquenta','sessenta','setenta','oitenta','noventa'];
  var cen = ['','cem','duzentos','trezentos','quatrocentos','quinhentos','seiscentos','setecentos','oitocentos','novecentos'];
  function g(n) {
    if (n===0) return '';
    if (n<20) return uns[n];
    if (n<100) { var d=Math.floor(n/10),u=n%10; return dez[d]+(u?' e '+uns[u]:''); }
    var c=Math.floor(n/100),r=n%100;
    return (c===1&&r>0?'cento':cen[c])+(r?' e '+g(r):'');
  }
  var partes = [];
  var rr = reais;
  if (rr>=1000000) { var m=Math.floor(rr/1000000); partes.push(g(m)+(m===1?' milhao':' milhoes')); rr%=1000000; }
  if (rr>=1000)    { var k=Math.floor(rr/1000);    partes.push(k===1?'mil':g(k)+' mil');           rr%=1000;    }
  if (rr>0)        { partes.push(g(rr)); }
  var reaisStr = partes.length ? partes.join(' e ')+(reais===1?' real':' reais') : '';
  var centStr  = cent>0 ? g(cent)+(cent===1?' centavo':' centavos') : '';
  if (reaisStr && centStr) return reaisStr+' e '+centStr;
  return reaisStr || centStr || 'zero reais';
}

function isMobile() { return window.innerWidth < 768; }

// Nome do cliente por reg (para páginas de pedidos/inove/etc)
function cliNomePed(reg) {
  if (!reg) return '';
  var c = clients.find(function(x){ return x.reg == reg; });
  return c ? c.nome : ('Cliente #' + reg);
}

// ── Relógio ───────────────────────────────────────────────────
(function tickRelogio() {
  var dias  = ['domingo','segunda-feira','terça-feira','quarta-feira','quinta-feira','sexta-feira','sábado'];
  var meses = ['janeiro','fevereiro','março','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro'];
  function atualiza() {
    var el = document.getElementById('relogio');
    if (!el) return;
    var d = new Date();
    var hh = String(d.getHours()).padStart(2,'0');
    var mm = String(d.getMinutes()).padStart(2,'0');
    var ss = String(d.getSeconds()).padStart(2,'0');
    el.textContent = dias[d.getDay()] + ', ' + d.getDate() + ' de ' + meses[d.getMonth()] + ' de ' + d.getFullYear() + ' - ' + hh + ':' + mm + ':' + ss;
  }
  atualiza();
  setInterval(atualiza, 1000);
})();

// ── Temas ─────────────────────────────────────────────────────
var THEMES = {
  sombra: {
    name:'Sombra', swatch:'#3b82f6',
    bg:'#0f1117', sbg:'#13151f', card:'#1a1d27', sec:'#22263a',
    hover:'#2d3250', active:'#1a2a40', border:'rgba(255,255,255,0.08)',
    text:'#e2e8f0', muted:'#94a3b8', dim:'#64748b',
    accent:'#3b82f6', success:'#22c55e', warn:'#fbbf24', danger:'#ef4444'
  },
  terminal: {
    name:'Terminal', swatch:'#00ff41',
    bg:'#010b01', sbg:'#010601', card:'#081408', sec:'#0b1e0b',
    hover:'#102810', active:'#0a200a', border:'rgba(0,255,65,0.12)',
    text:'#a8ffb8', muted:'#4db860', dim:'#2a6e3a',
    accent:'#00ff41', success:'#00cc33', warn:'#c8ff00', danger:'#ff3333'
  },
  forja: {
    name:'Forja', swatch:'#d4a017',
    bg:'#120e06', sbg:'#0e0a04', card:'#1c1508', sec:'#261c0a',
    hover:'#30220c', active:'#281a08', border:'rgba(180,130,20,0.18)',
    text:'#ead6a0', muted:'#a08050', dim:'#6b5535',
    accent:'#d4a017', success:'#78b040', warn:'#e8b420', danger:'#c0392b'
  },
  trincheira: {
    name:'Trincheira', swatch:'#7a9a3c',
    bg:'#09100a', sbg:'#060d07', card:'#111a0f', sec:'#182015',
    hover:'#1e2a1a', active:'#182415', border:'rgba(100,130,60,0.18)',
    text:'#c0c8b0', muted:'#7a8c68', dim:'#4e5a42',
    accent:'#7a9a3c', success:'#6b8c42', warn:'#b8a040', danger:'#9c3a2a'
  },
  cosmos: {
    name:'Cosmos', swatch:'#00b4d8',
    bg:'#04081a', sbg:'#020612', card:'#081428', sec:'#0c1c38',
    hover:'#102240', active:'#0c1e3a', border:'rgba(0,180,216,0.14)',
    text:'#c0e8f8', muted:'#5aaccc', dim:'#2e7a9a',
    accent:'#00b4d8', success:'#48cae4', warn:'#90e0ef', danger:'#ef476f'
  },
  codigo: {
    name:'Código', swatch:'#007acc',
    bg:'#1e1e1e', sbg:'#252526', card:'#252526', sec:'#2d2d30',
    hover:'#37373d', active:'#094771', border:'rgba(255,255,255,0.1)',
    text:'#d4d4d4', muted:'#888888', dim:'#6a6a6a',
    accent:'#007acc', success:'#4ec9b0', warn:'#dcdcaa', danger:'#f44747'
  }
};

var currentTheme = localStorage.getItem('ideali-theme') || 'sombra';

function applyTheme(name) {
  var t = THEMES[name]; if (!t) return;
  currentTheme = name;
  localStorage.setItem('ideali-theme', name);
  var css = [
    'body{background:'+t.bg+' !important;color:'+t.text+' !important}',
    '.card{background:'+t.card+' !important;border-color:'+t.border+' !important}',
    '#sidebar{background:'+t.sbg+' !important;border-color:'+t.border+' !important}',
    '.sb-logo{border-color:'+t.border+' !important}',
    '.sb-item:hover{background:'+t.hover+' !important;color:'+t.text+' !important}',
    '.sb-item.active{background:'+t.active+' !important;color:'+t.accent+' !important}',
    '.sb-icon{background:'+t.sec+' !important}',
    '.sb-divider{background:'+t.border+' !important}',
    '.sb-close{background:'+t.sec+' !important;color:'+t.muted+' !important;border-color:'+t.border+' !important}',
    '.hamburger{background:'+t.sec+' !important;color:'+t.muted+' !important;border-color:'+t.border+' !important}',
    '.hamburger:hover{background:'+t.hover+' !important;color:'+t.text+' !important}',
    'input,select{background:'+t.sec+' !important;color:'+t.text+' !important;border-color:'+t.border+' !important}',
    'input::placeholder{color:'+t.dim+' !important}',
    'input:focus,select:focus{border-color:'+t.accent+' !important;box-shadow:0 0 0 3px '+t.accent+'28 !important}',
    '.row-item:hover{background:'+t.hover+' !important}',
    '.row-item.active{background:'+t.active+' !important}',
    '.task-item{background:'+t.sec+' !important;border-color:'+t.border+' !important}',
    '.fin-card{background:'+t.sec+' !important}',
    '.counter-card{background:'+t.card+' !important;border-color:'+t.border+' !important}',
    '.tab-tarefa{background:'+t.sec+' !important;color:'+t.muted+' !important;border-color:'+t.border+' !important}',
    '.tab-tarefa:hover{background:'+t.hover+' !important;color:'+t.text+' !important}',
    '.tab-tarefa.active{background:'+t.active+' !important;color:'+t.accent+' !important;border-color:'+t.accent+' !important}',
    '.task-add-btn{background:'+t.accent+' !important}',
    '.task-add-btn:hover{filter:brightness(1.15)}',
    '.save-btn{background:'+t.accent+' !important}',
    '.save-btn:hover{filter:brightness(1.15)}',
    '.sync-dot{background:'+t.success+' !important}',
    '.sync-dot.error{background:'+t.danger+' !important}',
    '.sync-dot.syncing{background:'+t.warn+' !important}',
    '.month-dd-btn{background:'+t.sec+' !important;color:'+t.text+' !important;border-color:'+t.border+' !important}',
    '.month-dd-btn:hover,.month-dd-btn:focus{background:'+t.hover+' !important}',
    '.month-dd-btn.cur{background:'+t.active+' !important;border-color:'+t.accent+' !important;color:'+t.accent+' !important}',
    '#month-dd-list{background:'+t.card+' !important;border-color:'+t.border+' !important}',
    '.month-dd-item:hover{background:'+t.hover+' !important;color:'+t.text+' !important}',
    '.month-dd-item.sel{background:'+t.active+' !important;color:'+t.accent+' !important}',
    '.dash-card{background:'+t.card+' !important;border-color:'+t.border+' !important}',
    '#sidebar-overlay{background:rgba(0,0,0,0.65) !important}',
    '.mob-back{background:'+t.sec+' !important;color:'+t.muted+' !important;border-color:'+t.border+' !important}',
    '.sealed-banner{background:'+t.active+' !important}'
  ].join('\n');
  var el = document.getElementById('theme-style');
  if (!el) { el = document.createElement('style'); el.id = 'theme-style'; document.head.appendChild(el); }
  el.textContent = css;
  renderThemePicker();
}

function renderThemePicker() {
  var p = document.getElementById('sb-theme-picker');
  var n = document.getElementById('sb-theme-name');
  if (!p) return;
  p.innerHTML = Object.keys(THEMES).map(function(k) {
    var t = THEMES[k];
    var active = k === currentTheme;
    return '<button onclick="applyTheme(\''+k+'\')" title="'+t.name+'" '+
      'style="width:26px;height:26px;border-radius:50%;background:'+t.swatch+';'+
      'border:'+(active?'3px solid #fff':'2px solid rgba(255,255,255,0.15)')+';'+
      'cursor:pointer;transition:transform 0.15s;outline:none" '+
      'onmouseover="document.getElementById(\'sb-theme-name\').textContent=\''+t.name+'\';this.style.transform=\'scale(1.2)\'" '+
      'onmouseout="document.getElementById(\'sb-theme-name\').textContent=\''+THEMES[currentTheme].name+'\';this.style.transform=\'scale(1)\'">'+
      '</button>';
  }).join('');
  if (n) n.textContent = THEMES[currentTheme].name;
}

// ── Navegação MPA ─────────────────────────────────────────────
// Mapeamento de target → arquivo HTML
var PAGE_MAP = {
  'home':           'home.html',
  'contas-receber': 'contas-receber.html',
  'clientes':       'contas-receber.html',
  'tarefas':        'tarefas.html',
  'inove':          'inove.html',
  'resumo':         'resumo.html',
  'dashboard':      'dashboard.html',
  'cadastro':       'cadastro.html',
  'pedidos':        'pedidos.html',
  'orcamento':      'orcamento.html',
  'cobranca':       'cobranca.html',
  'recibo':         'recibo.html',
  'gastos':         'gastos.html',
  'relatorios':     'relatorios.html',
  'ordens-cam':     'ordens-cam.html',
  'tabela-precos':  'tabela-precos.html'
};

function sbNav(target) {
  closeSidebar();
  var page = PAGE_MAP[target];
  if (page) {
    window.location.href = page;
  }
}

function openSidebar() {
  var sb = document.getElementById('sidebar');
  var ov = document.getElementById('sidebar-overlay');
  if (sb) sb.classList.add('open');
  if (ov) ov.classList.add('open');
  updateSidebarActive();
  renderThemePicker();
  if (GROQ_API_KEY) {
    var el = document.getElementById('sb-groq-key');
    if (el) el.value = GROQ_API_KEY;
  }
}

function closeSidebar() {
  var sb = document.getElementById('sidebar');
  var ov = document.getElementById('sidebar-overlay');
  if (sb) sb.classList.remove('open');
  if (ov) ov.classList.remove('open');
}

function updateSidebarActive() {
  var path = window.location.pathname;
  var currentPage = path.split('/').pop() || 'home.html';
  var targetMap = {
    'home.html':            'home',
    'contas-receber.html':  'clientes',
    'tarefas.html':         'tarefas',
    'inove.html':           'inove',
    'resumo.html':          'resumo',
    'dashboard.html':       'dashboard',
    'cadastro.html':        'cadastro',
    'pedidos.html':         'pedidos',
    'orcamento.html':       'orcamento',
    'cobranca.html':        'cobranca',
    'recibo.html':          'recibo',
    'gastos.html':          'gastos',
    'relatorios.html':      'relatorios',
    'ordens-cam.html':      'ordens-cam',
    'tabela-precos.html':   'tabela-precos'
  };
  var activeId = targetMap[currentPage] || 'home';
  ['home','clientes','tarefas','inove','resumo','dashboard','cadastro','pedidos',
   'orcamento','cobranca','recibo','gastos','relatorios','ordens-cam','tabela-precos'].forEach(function(v) {
    var el = document.getElementById('sb-' + v);
    if (el) el.classList.toggle('active', activeId === v);
  });
}

document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') { closeSidebar(); closeIAPanel(); }
});

// ── Painel IA (Groq) ─────────────────────────────────────────
var GROQ_API_KEY = localStorage.getItem('ideali-groq-key') || '';
var iaHistory    = JSON.parse(localStorage.getItem('ideali-ia-history') || '[]');
var iaMicActive  = false;
var iaSpeechRec  = null;

function saveGroqKey() {
  var el = document.getElementById('sb-groq-key');
  if (!el) return;
  GROQ_API_KEY = el.value.trim();
  localStorage.setItem('ideali-groq-key', GROQ_API_KEY);
  var st = document.getElementById('sb-groq-status');
  if (st) st.textContent = GROQ_API_KEY ? '✓ Chave salva' : '';
}

function openIAPanel() {
  document.getElementById('ia-overlay').classList.add('open');
  document.getElementById('ia-panel').classList.add('open');
  var keyEl = document.getElementById('sb-groq-key');
  if (keyEl) keyEl.value = GROQ_API_KEY;
  renderIAHistory();
  setTimeout(function() { var el = document.getElementById('ia-input'); if (el) el.focus(); }, 300);
}

function closeIAPanel() {
  document.getElementById('ia-overlay').classList.remove('open');
  document.getElementById('ia-panel').classList.remove('open');
  iaStopMic();
}

function iaSetStatus(msg, type) {
  var el = document.getElementById('ia-status');
  if (!el) return;
  el.className = 'ia-status' + (type ? ' ' + type : '');
  el.textContent = msg;
}

function iaToggleMic() {
  if (iaMicActive) { iaStopMic(); return; }
  iaStartMic();
}

function iaStartMic() {
  var SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SR) { iaSetStatus('Reconhecimento de voz não suportado neste navegador.', 'error'); return; }
  iaSpeechRec = new SR();
  iaSpeechRec.lang = 'pt-BR';
  iaSpeechRec.continuous = false;
  iaSpeechRec.interimResults = false;
  iaSpeechRec.onresult = function(e) {
    var text = e.results[0][0].transcript;
    var inp  = document.getElementById('ia-input');
    if (inp) inp.value = (inp.value ? inp.value + ' ' : '') + text;
    iaStopMic();
  };
  iaSpeechRec.onerror = function(e) {
    iaSetStatus('Erro no microfone: ' + e.error, 'error');
    iaStopMic();
  };
  iaSpeechRec.onend = function() { if (iaMicActive) iaStopMic(); };
  iaSpeechRec.start();
  iaMicActive = true;
  var btn = document.getElementById('ia-mic-btn');
  if (btn) btn.classList.add('recording');
  var lbl = document.getElementById('ia-mic-label');
  if (lbl) lbl.textContent = '🔴 Gravando… fale seu comando em português';
}

function iaStopMic() {
  if (iaSpeechRec) { try { iaSpeechRec.stop(); } catch(e){} iaSpeechRec = null; }
  iaMicActive = false;
  var btn = document.getElementById('ia-mic-btn');
  if (btn) btn.classList.remove('recording');
  var lbl = document.getElementById('ia-mic-label');
  if (lbl) lbl.textContent = '';
}

var IA_SYSTEM_PROMPT = 'Você é um assistente de gestão de laboratório odontológico. Recebe comandos em linguagem natural e retorna APENAS um JSON válido (sem markdown, sem explicação extra) com a ação a executar.\n\n' +
'Clientes disponíveis (use o campo reg como cliente_reg):\n{{CLIENTES}}\n\n' +
'Mês atual: {{MES_ATUAL}}. Mês anterior: {{MES_ANTERIOR}}.\n\n' +
'Tabelas Supabase disponíveis — use SOMENTE as colunas listadas, sem campos extras:\n' +
'- controle_mensal: {cliente_reg, mes, ano, valor_mes, valor_pago, valor_componente, obs_pagamento, recebido, enviado, quitado}\n' +
'- tarefas: {texto, concluida, status, arquivada, cliente_reg, data} — status: pendente|em_execucao|concluida\n' +
'- inove_pedidos: {descricao, cliente_reg, status, data_pedido} — status: pendente|em_execucao|finalizado — para serviços Inove 3D\n' +
'- pedidos: {descricao, cliente_reg, valor, data_prevista, status, observacao, urgente} — status: orcamento|producao|enviado|entregue|cancelado — para pedidos de laboratório\n' +
'- gastos_entrega: {valor, tipo, descricao, data, cliente_reg, mes, ano} — tipo: correio|motoboy|uber|outro\n' +
'- cadastro_clientes: {reg, nome, cpf, cro, end, bairro, cidade, uf, cep, tel, obs}\n\n' +
'Tabela de preços atual (use para calcular o campo "valor" ao inserir pedidos):\n{{TABELA_PRECOS}}\n\n' +
'Regras de cálculo de valor para pedidos:\n' +
'- Identifique o material (zircônia, emax) e conte a quantidade de elementos na descrição\n' +
'- Se for prova/experimentação, use o valor_unitario do tipo "prova"\n' +
'- Multiplique valor_unitario × quantidade de elementos\n' +
'- Some adicionais (componente_neodent, componente_sin) se mencionados e o cliente não enviar o próprio componente\n' +
'- Se não conseguir calcular o valor, use 0\n\n' +
'Operações suportadas: insert | update | upsert.\n' +
'Para update e upsert inclua "where": {campo: valor} indicando o filtro.\n' +
'Para controle_mensal sempre use upsert com where: {cliente_reg, mes, ano}.\n' +
'IMPORTANTE: o campo "dados" deve conter APENAS colunas da tabela escolhida. Nunca inclua "cliente" (nome texto), "tipo_gasto" ou outros campos não listados.\n\n' +
'Retorne EXATAMENTE este JSON (sem texto extra):\n' +
'{"acao":"insert|update|upsert","tabela":"nome","dados":{campos},"where":{filtro_opcional},"mensagem":"confirmação em português"}\n\n' +
'Se o comando for ambíguo ou inválido, retorne:\n' +
'{"acao":"erro","tabela":"","dados":{},"mensagem":"explicação em português"}';

var IA_ALLOWED_COLS = {
  controle_mensal:   ['cliente_reg','mes','ano','valor_mes','valor_pago','valor_componente','obs_pagamento','recebido','enviado','quitado'],
  tarefas:           ['texto','concluida','status','arquivada','cliente_reg','data'],
  inove_pedidos:     ['descricao','cliente_reg','status','data_pedido'],
  pedidos:           ['descricao','cliente_reg','valor','data_prevista','status','observacao'],
  gastos_entrega:    ['valor','tipo','descricao','data','cliente_reg','mes','ano'],
  cadastro_clientes: ['reg','nome','cpf','cro','end','bairro','cidade','uf','cep','tel','obs']
};

function iaFilterCols(table, obj) {
  var allowed = IA_ALLOWED_COLS[table];
  if (!allowed) return obj;
  var out = {};
  allowed.forEach(function(k) { if (obj[k] !== undefined) out[k] = obj[k]; });
  return out;
}

async function iaRunAction(p) {
  var table = p.tabela;
  var dados = p.dados || {};
  var where = p.where || {};
  var res;

  if (!IA_ALLOWED_COLS[table]) {
    throw new Error('Tabela inválida: "' + table + '". Permitidas: ' + Object.keys(IA_ALLOWED_COLS).join(', '));
  }

  if (table === 'tarefas'       && !dados.data)        dados.data        = todayISO();
  if (table === 'inove_pedidos' && !dados.data_pedido) dados.data_pedido = todayISO();
  if (table === 'gastos_entrega' && !dados.data)       dados.data        = todayISO();
  if (table === 'controle_mensal') {
    if (dados.mes === undefined) dados.mes = currentMonth;
    if (dados.ano === undefined) dados.ano = currentYear;
    if (where.mes === undefined) where.mes = dados.mes;
    if (where.ano === undefined) where.ano = dados.ano;
  }
  if (table === 'gastos_entrega') {
    if (dados.mes === undefined) dados.mes = viewMonth;
    if (dados.ano === undefined) dados.ano = viewYear;
  }

  dados = iaFilterCols(table, dados);

  if (p.acao === 'insert') {
    res = await sb.from(table).insert(dados);
  } else if (p.acao === 'update') {
    var q = sb.from(table).update(dados);
    Object.keys(where).forEach(function(k) { q = q.eq(k, where[k]); });
    res = await q;
  } else if (p.acao === 'upsert') {
    var conflictCols = Object.keys(where).join(',') || undefined;
    var payload = Object.assign({}, dados, where);
    res = await sb.from(table).upsert(payload, conflictCols ? { onConflict: conflictCols } : undefined);
  } else {
    throw new Error('Ação não reconhecida: ' + p.acao);
  }

  if (res && res.error) throw new Error(res.error.message);

  // Recarrega a view atual se a função existir na página
  if (table === 'tarefas'          && typeof loadTarefas          === 'function') await loadTarefas();
  if (table === 'inove_pedidos'    && typeof loadInovePedidos     === 'function') await loadInovePedidos();
  if (table === 'pedidos'          && typeof loadPedidos          === 'function') await loadPedidos();
  if (table === 'gastos_entrega'   && typeof loadGastos           === 'function') await loadGastos();
  if (table === 'controle_mensal'  && typeof loadMonthData        === 'function') {
    var newState = await loadMonthData(viewMonth, viewYear);
    if (typeof renderClientList === 'function') renderClientList();
    if (typeof renderDetail     === 'function') renderDetail(typeof selected !== 'undefined' ? selected : null);
  }
  if (table === 'cadastro_clientes' && typeof loadCadastroClientes === 'function') await loadCadastroClientes();
}

async function executeIA() {
  var inp = document.getElementById('ia-input');
  var btn = document.getElementById('ia-exec-btn');
  if (!inp) return;
  var prompt = inp.value.trim();
  if (!prompt) { iaSetStatus('Digite um comando primeiro.', 'error'); return; }
  if (!GROQ_API_KEY) {
    iaSetStatus('Configure a chave Groq no menu lateral (⚙️ Chave Groq).', 'error');
    return;
  }

  btn.disabled = true; btn.style.opacity = '0.55';
  iaSetStatus('⏳ Processando com IA…', 'loading');
  iaStopMic();

  var clientList = clients.map(function(c) { return c.reg + ': ' + c.nome; }).join('\n');
  var precosStr = '';
  try {
    var precosRes = await sb.from('tabela_precos').select('material,tipo,valor_unitario,observacao').order('material').order('tipo');
    if (!precosRes.error && precosRes.data) {
      precosStr = precosRes.data.map(function(r){
        return '- ' + r.material + ' (' + r.tipo + '): R$ ' + r.valor_unitario + (r.observacao ? ' — ' + r.observacao : '');
      }).join('\n');
    }
  } catch(e) {}

  var now2   = new Date();
  var mesAtualNome = MESES[now2.getMonth()] + ' ' + now2.getFullYear() + ' (mes=' + now2.getMonth() + ', ano=' + now2.getFullYear() + ')';
  var prevM  = now2.getMonth() === 0 ? 11 : now2.getMonth() - 1;
  var mesAnteriorNome = MESES[prevM] + ' (mes=' + prevM + ')';
  var systemPrompt = IA_SYSTEM_PROMPT
    .replace('{{CLIENTES}}', clientList)
    .replace('{{TABELA_PRECOS}}', precosStr || '(não disponível)')
    .replace('{{MES_ATUAL}}', mesAtualNome)
    .replace('{{MES_ANTERIOR}}', mesAnteriorNome);

  try {
    var res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + GROQ_API_KEY
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user',   content: prompt }
        ],
        max_tokens: 1000,
        temperature: 0.1
      })
    });

    if (!res.ok) {
      var errData = {}; try { errData = await res.json(); } catch(e2) {}
      var msg = (errData.error && errData.error.message) ? errData.error.message : 'Erro HTTP ' + res.status;
      throw new Error(msg);
    }

    var data = await res.json();
    var raw  = data.choices[0].message.content.trim();
    raw = raw.replace(/^```json?\s*/i, '').replace(/\s*```$/i, '').trim();

    var parsed;
    try { parsed = JSON.parse(raw); }
    catch(e3) { throw new Error('Resposta inválida da IA: ' + raw.substring(0, 120)); }

    if (parsed.acao === 'erro') {
      iaSetStatus('⚠️ ' + parsed.mensagem, 'error');
      iaAddToHistory(prompt, parsed.mensagem, false);
      return;
    }

    await iaRunAction(parsed);
    iaSetStatus('✅ ' + parsed.mensagem, 'success');
    iaAddToHistory(prompt, parsed.mensagem, true);
    inp.value = '';

  } catch(e) {
    console.error('[IA]', e);
    iaSetStatus('❌ ' + (e.message || 'Falha na requisição'), 'error');
    iaAddToHistory(prompt, 'Erro: ' + (e.message || 'desconhecido'), false);
  } finally {
    btn.disabled = false; btn.style.opacity = '';
  }
}

function iaAddToHistory(cmd, result, ok) {
  var n  = new Date();
  var time = n.getHours().toString().padStart(2,'0') + ':' + n.getMinutes().toString().padStart(2,'0');
  iaHistory.unshift({ cmd: cmd, result: result, ok: ok, time: time });
  if (iaHistory.length > 10) iaHistory.pop();
  try { localStorage.setItem('ideali-ia-history', JSON.stringify(iaHistory)); } catch(e) {}
  renderIAHistory();
}

function iaClearHistory() {
  iaHistory = [];
  try { localStorage.removeItem('ideali-ia-history'); } catch(e) {}
  renderIAHistory();
}

function renderIAHistory() {
  var el = document.getElementById('ia-history');
  if (!el) return;
  if (!iaHistory.length) {
    el.innerHTML = '<p style="font-size:13px;color:#4a5568;text-align:center;padding:16px 0">Nenhum comando executado ainda.</p>';
    return;
  }
  el.innerHTML = iaHistory.map(function(h) {
    return '<div class="ia-history-item">' +
      '<div class="ia-history-cmd">' + escHtml(h.cmd) + '</div>' +
      '<div class="ia-history-res" style="color:' + (h.ok ? '#4ade80' : '#fca5a5') + '">' + escHtml(h.result) + '</div>' +
      '<div class="ia-history-time">' + escHtml(h.time) + '</div>' +
      '</div>';
  }).join('');
}

// ── Autenticação por senha ────────────────────────────────────
var IDEALI_PASSWORD = 'ideali2026';

(function checkAuth() {
  if (sessionStorage.getItem('ideali-auth') === 'ok') return;

  function injectLogin() {
    var overlay = document.createElement('div');
    overlay.id = 'auth-overlay';
    overlay.style.cssText = [
      'position:fixed','inset:0','background:#0f1117','z-index:99999',
      'display:flex','align-items:center','justify-content:center',
      'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif'
    ].join(';');
    overlay.innerHTML =
      '<div style="background:#1a1d27;border:0.5px solid rgba(255,255,255,0.1);border-radius:16px;padding:32px 28px;width:min(340px,90vw);text-align:center">'+
        '<p style="font-size:30px;margin-bottom:8px">🦷</p>'+
        '<p style="font-size:18px;font-weight:600;color:#f1f5f9;margin-bottom:4px">Ideali Laboratório</p>'+
        '<p style="font-size:13px;color:#64748b;margin-bottom:24px">Digite a senha para continuar</p>'+
        '<input id="auth-inp" type="password" placeholder="Senha" autocomplete="current-password" '+
          'style="width:100%;height:40px;background:#0f1117;border:0.5px solid rgba(255,255,255,0.15);'+
          'border-radius:8px;padding:0 14px;font-size:14px;color:#e2e8f0;outline:none;font-family:inherit;margin-bottom:10px"/>'+
        '<p id="auth-err" style="font-size:12px;color:#ef4444;margin-bottom:10px;min-height:16px"></p>'+
        '<button id="auth-btn" '+
          'style="width:100%;height:40px;background:#1d4ed8;border:none;border-radius:8px;'+
          'color:#fff;font-size:14px;font-weight:600;cursor:pointer;font-family:inherit">Entrar</button>'+
      '</div>';
    document.body.appendChild(overlay);
    document.getElementById('auth-inp').focus();

    function tryLogin() {
      var val = (document.getElementById('auth-inp').value || '').trim();
      if (val === IDEALI_PASSWORD) {
        sessionStorage.setItem('ideali-auth', 'ok');
        document.getElementById('auth-overlay').remove();
      } else {
        var err = document.getElementById('auth-err');
        var inp = document.getElementById('auth-inp');
        if (err) err.textContent = 'Senha incorreta. Tente novamente.';
        if (inp) {
          inp.value = '';
          inp.style.borderColor = '#ef4444';
          inp.focus();
          setTimeout(function(){ inp.style.borderColor = ''; }, 1500);
        }
      }
    }

    document.getElementById('auth-btn').addEventListener('click', tryLogin);
    document.getElementById('auth-inp').addEventListener('keydown', function(e){
      if (e.key === 'Enter') tryLogin();
    });
  }

  if (document.body) { injectLogin(); }
  else { document.addEventListener('DOMContentLoaded', injectLogin); }
})();

// Inicializa tema ao carregar
applyTheme(currentTheme);
