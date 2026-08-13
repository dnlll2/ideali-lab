-- ============================================================
-- Ideali Laboratorio - Ordens CAM
-- Arquivamento automatico de pedidos finalizados ha mais de 30 dias.
-- Ate aqui so existia o botao manual "📦 Arquivar" por card
-- (camArchivar, ordens-cam.html) -- a coluna Finalizado ia acumulando
-- indefinidamente ate alguem arquivar um por um.
--
-- Usa pg_cron (extensao ja disponivel no projeto, so precisava ser
-- habilitada) rodando 1x por dia -- roda direto no banco, nao
-- depende de ninguem abrir o ordens-cam.html pra acontecer.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

create extension if not exists pg_cron;

create or replace function arquivar_ordens_finalizadas_antigas()
returns void
language sql
security definer
set search_path = public
as $$
  update ordens_exocad
    set arquivado = true
    where status = 'finalizado'
      and coalesce(arquivado, false) = false
      and coalesce(excluido, false) = false
      and finalizado_at is not null
      and finalizado_at < now() - interval '30 days';
$$;

-- cron.schedule com um jobname que ja existe atualiza o job (nao
-- duplica) -- seguro rodar este arquivo de novo.
select cron.schedule(
  'arquivar-ordens-finalizadas-30d',
  '0 6 * * *',
  $$select arquivar_ordens_finalizadas_antigas();$$
);
