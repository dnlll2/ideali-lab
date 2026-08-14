-- ============================================================
-- Ideali Laboratorio - Saldo entre meses (devedor/credor)
-- Saldo devedor (cliente pagou menos que faturou no mes anterior) e so
-- aviso, calculado em tempo real em contas-receber.html/pagamentos-inove.html
-- comparando valor_pago x valor_mes do mes anterior -- nao precisa de coluna.
--
-- Saldo credor (cliente pagou a mais) precisa de uma decisao manual da
-- Ideali (pagamento a mais pode ser adiantamento de servico futuro, nao
-- sobra de fato) -- por isso vira coluna: null = pendente (padrao), true =
-- abatido do Restante do mes seguinte, false = recusado (mantido a parte).
-- Decidido em contas-receber.html; pagamentos-inove.html so le, sem botao.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

alter table controle_mensal
  add column if not exists abater_saldo_credor boolean;
