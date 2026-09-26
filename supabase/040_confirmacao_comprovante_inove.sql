-- ============================================================
-- Ideali Laboratorio - Confirmacao de comprovante pela Inove
-- No Historico Geral (pagamentos-inove.html) a Inove confirma cada
-- comprovante individualmente ("Realmente conferiu o comprovante?").
--
-- visto_inove_em    : quando a Inove clicou em "Ver" no comprovante.
--                     Enquanto for null, aparece "Comprovante novo".
-- confirmado_inove_em: quando a Inove confirmou que o comprovante bate.
--
-- Independente de controle_mensal.confirmado_pela_inove (confirmacao
-- do mes inteiro, botao "Confirmado" na linha do cliente).
--
-- Comprovantes que ja existiam entram como vistos (sem etiqueta
-- "novo") e nao confirmados.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

alter table pagamento_aportes add column if not exists visto_inove_em timestamptz;
alter table pagamento_aportes add column if not exists confirmado_inove_em timestamptz;

update pagamento_aportes set visto_inove_em = now() where visto_inove_em is null;
