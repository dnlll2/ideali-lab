-- ============================================================
-- Ideali Laboratorio - 050 Anular pagamento (sem apagar)
-- Um pagamento anulado continua guardado, com quando, quem e o motivo,
-- mas extratos e somas passam a ignorar. So o dono anula (a trava da
-- 049 ja impede a Inove de mexer nesses campos).
-- NAO muda o valor pago de nenhum mes.
-- Desfazer: ver o fim do arquivo.
-- ============================================================
alter table public.pagamento_aportes add column if not exists anulado_em     timestamptz;
alter table public.pagamento_aportes add column if not exists anulado_por    uuid;
alter table public.pagamento_aportes add column if not exists anulado_motivo text;

-- Talia Estefanelli Sampaio (reg 17), competencia jul/2026: o lancamento "legado" de R$ 2.590
-- repete o dinheiro dos dois Pix com comprovante (R$ 2.200 em 05/08 + R$ 390 em 05/06).
update public.pagamento_aportes
   set anulado_em = now(),
       anulado_por = (select dono_id from public.ideali_config where id),
       anulado_motivo = 'Duplicado: repete os Pix de R$ 2.200 (05/08/2026) e R$ 390 (05/06/2026), que tem comprovante. Anulado em 18/10/2026 a pedido do dono.'
 where id = 'f8730592-6d58-4151-bd55-8ce264c89ee3'
   and legado = true and valor = 2590 and anulado_em is null;

-- Conferencia (deve mostrar 1 linha anulada):
select id, valor, data_pagamento, legado, anulado_em, anulado_motivo
  from public.pagamento_aportes
 where cliente_reg = 17 and mes = 6 and ano = 2026
 order by created_at;

-- Desfazer:
-- update public.pagamento_aportes set anulado_em = null, anulado_por = null, anulado_motivo = null
--  where id = 'f8730592-6d58-4151-bd55-8ce264c89ee3';
-- alter table public.pagamento_aportes drop column anulado_em, drop column anulado_por, drop column anulado_motivo;
