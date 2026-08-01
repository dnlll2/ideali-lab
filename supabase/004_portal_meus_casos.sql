-- ============================================================
-- Ideali Laboratorio - Portal de Clientes
-- Etapa 3: Painel "Meus casos" - lista TODOS os casos do cliente
-- logado em ordens_exocad, independente da origem (portal, whatsapp,
-- email), com data de entrada e previsao de saida (7 dias uteis,
-- com regra das 14h).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 001_portal_convites.sql e 003_portal_caso.sql. Seguro rodar de
-- novo (funcoes usam CREATE OR REPLACE).
--
-- Mesmo padrao de seguranca das etapas anteriores: a funcao e
-- SECURITY DEFINER e valida a sessao (portal_sessoes) antes de
-- devolver qualquer linha; o cliente_reg usado no filtro vem da
-- sessao validada, nunca de um parametro que o cliente poderia
-- manipular, entao um cliente nunca enxerga o caso de outro.
-- ============================================================

-- Soma N dias uteis (seg-sex) a uma data, contando a partir do dia
-- seguinte (padrao usual de "prazo de entrega em N dias uteis").
create or replace function business_days_add(p_data date, p_dias int)
returns date
language plpgsql
security definer
set search_path = public
as $$
declare
  v_date  date := p_data;
  v_added int := 0;
begin
  while v_added < p_dias loop
    v_date := v_date + 1;
    if extract(dow from v_date) not in (0, 6) then
      v_added := v_added + 1;
    end if;
  end loop;
  return v_date;
end;
$$;

create or replace function listar_meus_casos(p_sessao text)
returns table(
  id             uuid,
  paciente       text,
  tipo_trabalho  text,
  status         text,
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
    where o.cliente_reg = v_sessao.reg
    order by o.created_at desc;
end;
$$;

grant execute on function listar_meus_casos(text) to anon;
