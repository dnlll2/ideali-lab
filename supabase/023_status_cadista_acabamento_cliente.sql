-- ============================================================
-- Ideali Laboratorio - Portal de Clientes
-- Mostrar pro cliente, em cada pedido: (1) o nome do cadista real
-- assim que o admin atribui um (ordens-cam.html, botao 🎯 Atribuir,
-- grava em ordens_exocad.cadista_reg -- ja existe desde
-- 005_portal_cadista_casos.sql, so nunca tinha sido exposto pro
-- cliente); (2) quando o pedido finalizado ja foi enviado pra Inove
-- (coluna enviado_inove, ja existe e e alternada manualmente pelo
-- botao 📤 Inove em ordens-cam.html) -- o front troca o rotulo de
-- "Finalizado" pra "Fase de Acabamento" nesse caso (o pedido continua
-- do mesmo jeito internamente, so status continua 'finalizado' --
-- nao criei um status novo pra nao mexer nas transicoes existentes
-- em atualizar_status_caso_cadista).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 015_excluir_caso_cliente.sql
-- (ultima versao de listar_meus_casos) ja ter rodado antes.
--
-- DROP necessario pq a lista de colunas de retorno muda (cadista_nome
-- e enviado_inove sao novas) -- Postgres nao deixa isso com CREATE OR
-- REPLACE.
-- ============================================================

drop function if exists listar_meus_casos(text);

create function listar_meus_casos(p_sessao text)
returns table(
  id             uuid,
  paciente       text,
  tipo_trabalho  text,
  status         text,
  cadista_nome   text,
  enviado_inove  boolean,
  criado_em      timestamptz,
  previsao_saida date
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao portal_sessoes%rowtype;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cliente' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  return query
    select
      o.id,
      coalesce(
        nullif(substring(o.descricao from 'Paciente: ([^\n]*)'), ''),
        nullif((regexp_match(o.descricao, '^Pac\s+(.+?)\s+-\s+'))[1], ''),
        nullif(trim(o.descricao), ''),
        '—'
      ) as paciente,
      coalesce(
        nullif(substring(o.descricao from 'Tipo de trabalho: ([^\n]*)'), ''),
        nullif((regexp_match(o.descricao, '^Pac\s+.+?\s+-\s+(.*)$'))[1], ''),
        ''
      ) as tipo_trabalho,
      o.status,
      ca.nome as cadista_nome,
      coalesce(o.enviado_inove, false) as enviado_inove,
      o.created_at,
      business_days_add(
        case
          when extract(hour from (o.created_at at time zone 'America/Sao_Paulo')) >= 14
            then ((o.created_at at time zone 'America/Sao_Paulo')::date + 1)
          else (o.created_at at time zone 'America/Sao_Paulo')::date
        end,
        7
      ) as previsao_saida
    from ordens_exocad o
    left join cadastro_cadistas ca on ca.cadista_reg = o.cadista_reg
    where o.cliente_reg = v_sessao.reg
      and coalesce(o.excluido, false) = false
    order by o.created_at desc;
end;
$$;

grant execute on function listar_meus_casos(text) to anon;
