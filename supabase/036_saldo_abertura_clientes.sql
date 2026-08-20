-- ============================================================
-- Ideali Laboratorio - Saldo de abertura por cliente
--
-- controle_mensal so tem historico a partir do mes em que a
-- Ideali comecou a lancar cada cliente (ex: Gilberto Ferreira
-- Esquivel, reg 22, so a partir de junho/2026). Mas a divida real
-- do cliente no Inove pode vir de antes disso -- o extrato deles
-- traz um "Saldo Anterior" que carrega historico que nunca foi
-- rastreado aqui.
--
-- Essa tabela guarda esse saldo de abertura, SEPARADO do
-- controle_mensal -- nunca se mistura com valor_mes/valor_pago de
-- um mes especifico (isso mentiria sobre o que foi faturado
-- naquele mes). E um ajuste explicito, datado e com fonte, nao um
-- numero forcado pra bater conta.
--
-- IMPORTANTE: verificado=false significa que o valor foi calculado
-- por diferenca (saldo real do extrato menos a soma do que ja
-- estava no controle_mensal), NAO conferido linha a linha contra
-- os extratos dos meses anteriores. Pode incluir erros de
-- lancamento desses meses, nao so divida de fato anterior ao
-- inicio do rastreio. So vira verificado=true quando alguem
-- conferir extrato por extrato.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

create table if not exists saldo_abertura_clientes (
  id uuid primary key default gen_random_uuid(),
  cliente_reg int not null references cadastro_clientes(reg),
  valor numeric not null,
  data_referencia date not null,
  fonte text,
  observacao text,
  verificado boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cliente_reg)
);

alter table saldo_abertura_clientes enable row level security;

create policy "saldo_abertura_clientes_service_role"
  on saldo_abertura_clientes for all
  using (true)
  with check (true);

insert into saldo_abertura_clientes (cliente_reg, valor, data_referencia, fonte, observacao, verificado)
values (
  22,
  4680.02,
  '2026-05-31',
  'Extrato Inove agosto/2026 (Saldo Anterior -6.300,00 em 01/08)',
  'Diferenca entre o saldo real do extrato (R$6.300,00 em 01/08/2026) e a soma de jun+jul+ago ja lancados no controle_mensal (net +R$1.619,98 devedor nesses 3 meses). NAO conferido linha a linha contra extratos de maio/junho/julho -- pode incluir erros de lancamento desses meses, nao so divida anterior a junho.',
  false
)
on conflict (cliente_reg) do update set
  valor = excluded.valor,
  data_referencia = excluded.data_referencia,
  fonte = excluded.fonte,
  observacao = excluded.observacao,
  verificado = excluded.verificado,
  updated_at = now();
