-- ============================================================
-- Ideali Laboratorio - Lancamento extratos Inove 3D (julho/2026)
--
-- Fatura (valor_mes) e pagamentos com Pix confirmado (valor_pago)
-- extraidos dos extratos individuais do Inove 3D Laboratorio,
-- periodo 01/07/2026 a 31/07/2026 (pasta Desktop/99).
--
-- So entra em valor_pago o que tinha "Pagamento Efetuado! / Pix"
-- no extrato. NAO conta descontos/acordos: Leonardo Moll teve
-- R$630 de "Desconto Aplicado! / Acordo" no extrato, que e
-- abatimento negociado, nao dinheiro recebido -- por isso o
-- valor_pago dele e so o Pix de R$1.035, nao R$1.665.
--
-- Luiz Henrique da Silva (CPF 058.886.078-60) nao existia em
-- cadastro_clientes; foi cadastrado aqui com reg 39 (proximo
-- livre; reg 14 ficou de fora por poder estar em uso em pedidos
-- antigos).
--
-- Idempotente: roda de novo sem duplicar (ON CONFLICT / upsert
-- manual por cliente_reg+mes+ano, mesmo padrao usado pelo app em
-- contas-receber.html / patchControleMensal).
-- Rode no SQL Editor do Supabase (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

insert into cadastro_clientes (reg, nome, cpf, end_str, bairro, cidade, uf, cep)
values (39, 'Luiz Henrique da Silva', '058.886.078-60', 'Rua Nicola Martins Romeira, 251', 'Centro', 'Ribeirao do Sul', 'SP', '19930-025')
on conflict (reg) do nothing;

do $$
declare
  v_mes int := 7;
  v_ano int := 2026;
  v_dados jsonb := '[
    {"reg":9,  "valor_mes":380.00,   "valor_pago":0.00},
    {"reg":27, "valor_mes":260.00,   "valor_pago":2135.00},
    {"reg":2,  "valor_mes":4746.00,  "valor_pago":1035.00},
    {"reg":21, "valor_mes":210.00,   "valor_pago":0.00},
    {"reg":28, "valor_mes":575.00,   "valor_pago":0.00},
    {"reg":16, "valor_mes":4441.90,  "valor_pago":178.30},
    {"reg":29, "valor_mes":2600.00,  "valor_pago":0.00},
    {"reg":19, "valor_mes":6508.00,  "valor_pago":2060.00},
    {"reg":26, "valor_mes":5510.00,  "valor_pago":260.00},
    {"reg":39, "valor_mes":260.00,   "valor_pago":0.00}
  ]'::jsonb;
  v_item jsonb;
  v_id uuid;
begin
  for v_item in select * from jsonb_array_elements(v_dados)
  loop
    select id into v_id from controle_mensal
      where cliente_reg = (v_item->>'reg')::int and mes = v_mes and ano = v_ano;

    if v_id is not null then
      update controle_mensal
        set valor_mes  = (v_item->>'valor_mes')::numeric,
            valor_pago = (v_item->>'valor_pago')::numeric,
            updated_at = now()
        where id = v_id;
    else
      insert into controle_mensal (cliente_reg, mes, ano, valor_mes, valor_pago)
        values (
          (v_item->>'reg')::int,
          v_mes, v_ano,
          (v_item->>'valor_mes')::numeric,
          (v_item->>'valor_pago')::numeric
        );
    end if;
  end loop;
end $$;
