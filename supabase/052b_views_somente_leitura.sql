-- ============================================================
-- Ideali Laboratorio - 052b Views da Inove: so leitura
--
-- Achado no teste de negacao da 052 (29/10/2026): o Supabase da por padrao
-- INSERT/UPDATE/DELETE em todo objeto novo do schema public para "authenticated".
-- inove_controle_mensal_v e uma view simples (atualizavel) e roda como dona da view,
-- entao um PATCH da Inove nela chegava ao controle_mensal: so o gatilho da 049
-- barrava (valor_pago). Nada passou do que a Inove ja pode (recebido/conferido),
-- mas a barreira tem que ser a permissao, nao so o gatilho.
--
-- Tira escrita das 3 views. A Inove grava so pelas funcoes inove_marcar_recebido /
-- inove_marcar_conferido (tela ja usa elas). Nao altera nenhum dado.
-- Desfazer: supabase/052b_desfazer.sql. Seguro rodar de novo.
-- ============================================================

begin;
revoke insert, update, delete, truncate, references, trigger on public.inove_clientes_v        from authenticated, anon, public;
revoke insert, update, delete, truncate, references, trigger on public.inove_controle_mensal_v from authenticated, anon, public;
revoke insert, update, delete, truncate, references, trigger on public.inove_config_v          from authenticated, anon, public;
grant select on public.inove_clientes_v, public.inove_controle_mensal_v, public.inove_config_v to authenticated;
commit;
