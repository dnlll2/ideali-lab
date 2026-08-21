-- ============================================================
-- Ideali Laboratorio - Conferencia automatica do comprovante (aportes)
--
-- contas-receber.html agora le o comprovante de cada aporte (imagem ou
-- PDF, print de Pix ou recibo de banco) com um modelo de visao (Groq)
-- e compara o valor lido com pagamento_aportes.valor, guardando o
-- resultado aqui -- e o que vira o selo "confere / diverge" no
-- Historico de Pagamentos (contas-receber.html e pagamentos-inove.html).
--
-- A leitura roda uma vez (no upload do aporte) e o resultado fica
-- salvo -- nao reprocessa a cada visita. Comprovantes anexados antes
-- desta funcionalidade existir passam por um backfill unico (rodado a
-- mao, uma vez, via console do navegador -- ver backfillConferenciaComprovantes
-- em contas-receber.html).
--
-- Rode no SQL Editor do Supabase (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

alter table pagamento_aportes
  add column if not exists conferencia_valor  numeric(10,2),
  add column if not exists conferencia_status text,
  add column if not exists conferencia_obs    text,
  add column if not exists conferido_em       timestamptz;

-- 'ok' | 'divergente' | 'sem_leitura' -- null = ainda nao processado
-- (comprovante antigo pendente de backfill, ou aporte 'legado' sem comprovante).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'pagamento_aportes_conferencia_status_check'
  ) then
    alter table pagamento_aportes
      add constraint pagamento_aportes_conferencia_status_check
      check (conferencia_status is null or conferencia_status in ('ok','divergente','sem_leitura'));
  end if;
end $$;
