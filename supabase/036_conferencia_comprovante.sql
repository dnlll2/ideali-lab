-- ============================================================
-- Ideali Laboratorio - Conferencia automatica do comprovante (aportes)
--
-- contas-receber.html agora le o comprovante de cada aporte com pdf.js +
-- regex local (mesma tecnica do extrato do Inove -- sem IA, sem chave,
-- sem chamada de rede) e compara o valor lido com pagamento_aportes.valor,
-- guardando o resultado aqui -- e o que vira o selo "confere / diverge" no
-- Historico de Pagamentos (contas-receber.html e pagamentos-inove.html).
-- So funciona pra PDF com texto selecionavel de verdade -- comprovante que
-- e foto/print (imagem, ou PDF escaneado) fica "sem_leitura" (conferencia_obs
-- explica o motivo: 'imagem' | 'pdf-sem-texto' | 'ambiguo' | 'erro').
--
-- A leitura roda uma vez (no upload do aporte) e o resultado fica salvo --
-- nao reprocessa a cada visita. Comprovantes anexados antes desta
-- funcionalidade existir sao cobertos pelo botao "Conferir comprovantes
-- antigos" no cabecalho (ver backfillConferenciaComprovantes em
-- contas-receber.html).
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
