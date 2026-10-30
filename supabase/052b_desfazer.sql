-- ============================================================
-- Ideali Laboratorio - DESFAZ a 052b (volta a escrita padrao do Supabase nas views)
-- Nao recomendado: reabre o caminho de PATCH pela view (so o gatilho da 049 barra).
-- ============================================================

begin;
grant insert, update, delete on public.inove_clientes_v, public.inove_controle_mensal_v, public.inove_config_v to authenticated;
commit;
