-- ============================================================
-- Ideali Laboratorio - Editar valor pago da comissao (Inove)
-- No modal "Pagar Comissao" (pagamentos-inove.html), o valor a
-- registrar como pago agora e editavel -- pode ser diferente do
-- 15% calculado (ex: acerto arredondado combinado com a Elisangela).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Seguro rodar de novo (ADD COLUMN
-- IF NOT EXISTS / CREATE OR REPLACE).
--
-- Editar o valor NAO muda quanto cada cliente "ja foi comissionado"
-- (valor_pago_comissionado continua avancando pelo valor cheio
-- calculado, como sempre) -- o valor editado e so o que fica
-- registrado em comissoes_pagas.valor_total (o "quanto realmente
-- saiu"). valor_calculado guarda o 15% original, pra dar pra ver
-- depois que houve ajuste manual.
-- ============================================================

alter table comissoes_pagas
  add column if not exists valor_calculado numeric(10,2);

-- Precisa dropar a versao antiga (2 parametros) antes de criar a nova (3
-- parametros) -- "create or replace" nao troca a assinatura, so o corpo de
-- uma funcao com os MESMOS parametros. Sem isso, ficariam as duas versoes
-- ao mesmo tempo (pagar_comissao(int,int) e pagar_comissao(int,int,numeric)),
-- e uma chamada com 2 argumentos ficaria ambigua entre elas.
drop function if exists pagar_comissao(int, int);

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

  v_final := coalesce(p_valor_total, v_total);

  insert into comissoes_pagas (mes, ano, valor_total, valor_calculado, detalhes_json)
  values (p_mes, p_ano, v_final, v_total, v_detalhes)
  returning id into v_novo_id;

  return jsonb_build_object('ok', true, 'id', v_novo_id, 'valor_total', v_final, 'valor_calculado', v_total, 'detalhes', v_detalhes);
end;
$$;

grant execute on function pagar_comissao(int, int, numeric) to anon;
