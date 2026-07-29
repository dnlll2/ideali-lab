-- ============================================================
-- Ideali Laboratorio - Comissao (Inove)
-- Adiciona o botao "Excluir Comissão Paga": desfaz um saque de
-- comissao ja confirmado (ex: saque de teste, ou engano).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 006_comissoes_pagas.sql
-- ja ter rodado antes (usa as tabelas/colunas criadas la).
--
-- Como funciona: pega o saque pelo id, e pra cada cliente que
-- entrou naquele saque, devolve valor_pago_comissionado pro valor
-- "anterior" que estava gravado no proprio saque (o quanto ja tinha
-- sido sacado ANTES daquele saque acontecer) -- depois apaga a linha
-- de comissoes_pagas. Tudo numa unica transacao.
--
-- Trava de seguranca: so deixa excluir o saque mais RECENTE do
-- mes/ano dele. Se tivesse dois saques no mesmo mes e voce apagasse
-- o mais antigo primeiro, o valor_pago_comissionado ia voltar pra
-- tras de um jeito que nao bate mais com o segundo saque (que ainda
-- estaria valendo) -- entao a funcao recusa e pede pra excluir na
-- ordem certa (do mais novo pro mais antigo).
-- ============================================================

create or replace function excluir_comissao_paga(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row comissoes_pagas%rowtype;
  v_det jsonb;
begin
  select * into v_row from comissoes_pagas where id = p_id for update;
  if v_row.id is null then
    return jsonb_build_object('ok', false, 'motivo', 'nao_encontrado');
  end if;

  if exists (
    select 1 from comissoes_pagas
    where mes = v_row.mes and ano = v_row.ano and data_pagamento > v_row.data_pagamento
  ) then
    return jsonb_build_object('ok', false, 'motivo', 'nao_e_o_mais_recente');
  end if;

  for v_det in select * from jsonb_array_elements(v_row.detalhes_json)
  loop
    update controle_mensal
      set valor_pago_comissionado = (v_det->>'valor_pago_comissionado_anterior')::numeric,
          updated_at = now()
      where cliente_reg = (v_det->>'cliente_reg')::int
        and mes = v_row.mes
        and ano = v_row.ano;
  end loop;

  delete from comissoes_pagas where id = p_id;

  return jsonb_build_object('ok', true, 'valor_total', v_row.valor_total, 'mes', v_row.mes, 'ano', v_row.ano);
end;
$$;

grant execute on function excluir_comissao_paga(uuid) to anon;
