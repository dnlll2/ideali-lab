-- ============================================================
-- Ideali Laboratorio - Notificacao de pagamento novo pra Inove
-- Adiciona o campo confirmado_pela_inove em controle_mensal: fica
-- false quando um pagamento (valor_pago + comprovante) e' registrado
-- em contas-receber.html, e volta pra true quando a Elisangela
-- confirma que viu em pagamentos-inove.html.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok).
--
-- Mesmo padrao do campo visto_pelo_admin (011_visto_pelo_admin.sql):
-- campo no banco em vez de "ultimo visto" no localStorage, pra bater
-- igual em qualquer navegador/computador e o "confirmar" ficar
-- registrado de verdade.
-- ============================================================

alter table controle_mensal add column if not exists confirmado_pela_inove boolean not null default true;
