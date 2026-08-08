-- ============================================================
-- Ideali Laboratorio - Vencimento mensal (Inove)
-- Data de vencimento de cada mes, usada em pagamentos-inove.html
-- pro badge "Vencimento" e pro ranking de pontualidade (bons
-- pagadores x atrasados).
--
-- Por padrao o vencimento e calculado automaticamente no
-- client-side (5o dia util do mes, pulando fim de semana e
-- feriados nacionais). Essa tabela so guarda uma LINHA quando
-- alguem sobrescreve manualmente aquele mes especifico (feriado
-- municipal, acordo pontual etc) -- mes sem override nao tem
-- linha aqui, e a pagina usa o calculo automatico.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Seguro rodar de novo (CREATE
-- TABLE IF NOT EXISTS).
-- ============================================================

create table if not exists vencimento_mensal (
  id                uuid primary key default gen_random_uuid(),
  mes               int not null,
  ano               int not null,
  data_vencimento   date not null,
  updated_at        timestamptz not null default now(),
  unique (mes, ano)
);
