-- ============================================================
-- Ideali Laboratorio - Divida total conforme ultimo extrato
--
-- Substitui toda a tentativa de calcular saldo entre meses (mes
-- anterior, saldo de abertura, credor/devedor acumulado -- ver
-- migrations 035 e 036) por UM campo simples: quanto o cliente
-- deve no total, direto do ultimo extrato do Inove que a Ideali
-- recebeu. Preenchido manualmente em contas-receber.html toda vez
-- que chega um extrato novo -- o sistema nao calcula mais nada
-- sozinho.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

alter table cadastro_clientes add column if not exists divida_total_extrato numeric;

drop table if exists saldo_abertura_clientes;

update cadastro_clientes set divida_total_extrato = 5930.00 where reg = 22;
