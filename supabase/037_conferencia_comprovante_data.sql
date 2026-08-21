-- ============================================================
-- Ideali Laboratorio - Data/hora lida do comprovante (conferencia)
--
-- Complementa 036_conferencia_comprovante.sql: alem do valor, a
-- conferencia agora tambem le a data/hora que o comprovante mostra
-- (regex local, mesmo pdf.js do extrato do Inove) e guarda aqui pra
-- exibir no selo quando o valor diverge -- ajuda a bater de frente com
-- a Inove quando questionam um pagamento (nao so "o valor bate", mas
-- "o comprovante mostra tal valor, nesse dia").
--
-- Texto livre (ex: "24/07/2026 14:32"), nao date/timestamp -- e so pra
-- exibicao, nao entra em filtro/ordenacao nenhuma.
--
-- Rode no SQL Editor do Supabase (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

alter table pagamento_aportes
  add column if not exists conferencia_data_texto text;
