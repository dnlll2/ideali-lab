-- ============================================================
-- Ideali Laboratorio - Estudio CAD: trabalhos por arcada e modelos
-- arcada_tipo: 'protocolo' ou 'placa' (placa de bruxismo); quando
--   preenchido o pedido e cobrado por arcada e nao usa dentes.
-- arcadas: quais arcadas do protocolo/placa ('sup', 'inf').
-- modelos: modelos gerados junto ('sup', 'inf'), cobrados a parte.
-- Os precos ficam em EC_PRECOS no estudio-cad.html; o valor final
-- continua salvo em estudio_pedidos.valor.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Seguro rodar de novo.
-- ============================================================

alter table estudio_pedidos add column if not exists arcada_tipo text;
alter table estudio_pedidos add column if not exists arcadas text[];
alter table estudio_pedidos add column if not exists modelos text[];
