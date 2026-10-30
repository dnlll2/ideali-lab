-- ============================================================
-- Ideali Laboratorio - Historico de pagamentos parcelados (Inove)
-- Cliente que paga picado (varias vezes ate quitar o mes) agora gera
-- 1 linha por pagamento em vez de um numero so em
-- controle_mensal.valor_pago -- cada linha tem data, valor e
-- comprovante proprios, visiveis tanto em contas-receber.html
-- (Ideali) quanto em pagamentos-inove.html (Elisangela).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Seguro rodar de novo (CREATE TABLE
-- IF NOT EXISTS).
--
-- controle_mensal.valor_pago continua sendo o campo que todo o resto
-- do sistema ja le (status, comissao, totais) -- a partir do
-- primeiro aporte lancado pra um cliente/mes, esse numero passa a
-- ser a SOMA dos aportes daquele cliente/mes (recalculado no
-- client-side a cada lancamento/exclusao). Meses sem nenhum aporte
-- continuam com valor_pago digitado a mao, exatamente como antes --
-- pagamentos antigos nao sao migrados.
--
-- legado=true marca um aporte criado automaticamente pra preservar
-- um valor_pago antigo (sem historico) no momento em que o primeiro
-- aporte de verdade e lancado naquele mes -- nao tem comprovante
-- proprio.
-- ============================================================

create table if not exists pagamento_aportes (
  id                uuid primary key default gen_random_uuid(),
  cliente_reg       int not null,
  mes               int not null,
  ano               int not null,
  valor             numeric(10,2) not null,
  data_pagamento    date not null default current_date,
  comprovante_path  text,
  comprovante_url   text,
  obs               text,
  legado            boolean not null default false,
  created_at        timestamptz not null default now()
);

create index if not exists pagamento_aportes_cliente_ano_mes_idx
  on pagamento_aportes (cliente_reg, ano, mes);
