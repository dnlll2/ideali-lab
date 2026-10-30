-- ============================================================
-- Ideali Laboratorio - Comissao Inove passa de 15% para 10%
-- Vale pra todos os meses (decisao em 01/10/2026). No front a
-- taxa vem de COMISSAO em shared.js; aqui e o calculo do "saque"
-- (pagar_comissao), que tinha 0.15 fixo.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Seguro rodar de novo (CREATE OR
-- REPLACE, mesma assinatura da 030).
--
-- Saques ja confirmados (comissoes_pagas) NAO sao recalculados --
-- continuam com o valor que foi pago na epoca.
-- ============================================================

create or replace function pagar_comissao(p_mes int, p_ano int, p_valor_total numeric default null)
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
  v_final     numeric(10,2);
begin
  for v_row in
    select id, cliente_reg, valor_pago, valor_pago_comissionado
    from controle_mensal
    where mes = p_mes and ano = p_ano
      and valor_pago > valor_pago_comissionado
    order by cliente_reg
    for update
  loop
    v_pendente := round((v_row.valor_pago - v_row.valor_pago_comissionado) * 0.10, 2);
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

  v_final := coalesce(p_valor_total, v_total);

  insert into comissoes_pagas (mes, ano, valor_total, valor_calculado, detalhes_json)
  values (p_mes, p_ano, v_final, v_total, v_detalhes)
  returning id into v_novo_id;

  return jsonb_build_object('ok', true, 'id', v_novo_id, 'valor_total', v_final, 'valor_calculado', v_total, 'detalhes', v_detalhes);
end;
$$;

grant execute on function pagar_comissao(int, int, numeric) to anon;
