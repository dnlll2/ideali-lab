-- ============================================================
-- Ideali Laboratorio - Comissao (Inove)
-- Adiciona o "saque" de comissao em pagamentos-inove.html: 15% sobre
-- o que os clientes ja pagaram (valor_pago em controle_mensal),
-- descontando o que ja foi sacado antes.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Seguro rodar de novo (ADD COLUMN
-- IF NOT EXISTS / CREATE TABLE IF NOT EXISTS / CREATE OR REPLACE).
--
-- Como evita contar a mesma comissao duas vezes:
-- valor_pago_comissionado (nova coluna em controle_mensal) guarda,
-- por cliente+mes+ano, ate quanto do valor_pago daquela linha ja
-- gerou uma comissao paga. A comissao pendente de uma linha e
-- sempre 15% * (valor_pago - valor_pago_comissionado) -- nunca
-- sobre o valor_pago inteiro. Ao confirmar um saque, a funcao move
-- valor_pago_comissionado ate o valor_pago atual, entao o mesmo
-- centavo nunca entra em dois saques, mesmo que valor_pago continue
-- subindo depois (pagamentos parciais do cliente).
--
-- A funcao roda tudo (ler linhas pendentes, atualizar
-- controle_mensal, inserir o registro historico) numa unica
-- transacao (padrao de funcao plpgsql), com FOR UPDATE travando as
-- linhas lidas -- se dois cliques em "Confirmar pagamento" caissem
-- ao mesmo tempo, o segundo so roda depois do primeiro terminar e
-- ve o saldo ja zerado, entao nao paga de novo.
-- ============================================================

alter table controle_mensal
  add column if not exists valor_pago_comissionado numeric(10,2) not null default 0;

create table if not exists comissoes_pagas (
  id             uuid primary key default gen_random_uuid(),
  data_pagamento timestamptz not null default now(),
  mes            int not null,
  ano            int not null,
  valor_total    numeric(10,2) not null,
  detalhes_json  jsonb not null,
  created_at     timestamptz not null default now()
);

create index if not exists comissoes_pagas_mes_ano_idx on comissoes_pagas (ano, mes);

create or replace function pagar_comissao(p_mes int, p_ano int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total     numeric(10,2) := 0;
  v_detalhes  jsonb := '[]'::jsonb;
  v_row       record;
  v_pendente  numeric(10,2);
  v_novo_id   uuid;
begin
  for v_row in
    select id, cliente_reg, valor_pago, valor_pago_comissionado
    from controle_mensal
    where mes = p_mes and ano = p_ano
      and valor_pago > valor_pago_comissionado
    order by cliente_reg
    for update
  loop
    v_pendente := round((v_row.valor_pago - v_row.valor_pago_comissionado) * 0.15, 2);
    if v_pendente > 0 then
      update controle_mensal
        set valor_pago_comissionado = v_row.valor_pago,
            updated_at = now()
        where id = v_row.id;

      v_total := v_total + v_pendente;
      v_detalhes := v_detalhes || jsonb_build_object(
        'cliente_reg', v_row.cliente_reg,
        'valor_pago', v_row.valor_pago,
        'valor_pago_comissionado_anterior', v_row.valor_pago_comissionado,
        'valor_base_comissao', v_row.valor_pago - v_row.valor_pago_comissionado,
        'comissao', v_pendente
      );
    end if;
  end loop;

  if v_total <= 0 then
    return jsonb_build_object('ok', false, 'motivo', 'sem_comissao_pendente');
  end if;

  insert into comissoes_pagas (mes, ano, valor_total, detalhes_json)
  values (p_mes, p_ano, v_total, v_detalhes)
  returning id into v_novo_id;

  return jsonb_build_object('ok', true, 'id', v_novo_id, 'valor_total', v_total, 'detalhes', v_detalhes);
end;
$$;

grant execute on function pagar_comissao(int, int) to anon;
