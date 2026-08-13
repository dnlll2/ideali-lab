-- ============================================================
-- Ideali Laboratorio - Unifica onde os dentes marcados ficam salvos
--
-- 024_dentes_ordens_exocad.sql criou ordens_exocad.dentes (coluna
-- real) pro odontograma do ordens-cam.html (admin). Mas o portal do
-- CLIENTE (portal-cliente.html) e mais antigo e nunca usou essa
-- coluna -- ele guarda os dentes so como texto dentro de descricao
-- ("Dentes: 26, 36"), e obter_caso_cliente reconstroi o array via
-- regex nesse texto.
--
-- Resultado: uma ordem criada/editada pelo ADMIN (com odontograma
-- gravando em ordens_exocad.dentes) nao tem a linha "Dentes: ..." no
-- formato que o regex do cliente espera -- o cliente abre o proprio
-- pedido e o odontograma aparece todo apagado, mesmo o admin ja tendo
-- marcado os dentes.
--
-- Esta migration faz as duas pontas conversarem com a MESMA coluna:
--  - obter_caso_cliente passa a preferir o.dentes (coluna real);
--    so cai pro regex em cima da descricao se a coluna estiver nula
--    (pedidos antigos, de antes da coluna existir).
--  - enviar_caso/editar_caso_cliente (fluxo do proprio cliente)
--    passam a gravar em ordens_exocad.dentes tambem, alem de manter
--    a linha de texto (usada noutros lugares, ex: listar_casos_cadista
--    ainda le "Dentes:" do texto pra portal-cadista.html).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 024_dentes_ordens_exocad.sql
-- e 018_editar_caso_cliente.sql ja terem rodado antes.
-- ============================================================

create or replace function enviar_caso(
  p_sessao        text,
  p_paciente      text,
  p_tipo_trabalho text,
  p_dentes        int[],
  p_cor           text,
  p_observacoes   text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao    portal_sessoes%rowtype;
  v_descricao text;
  v_id        uuid;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cliente' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  if p_paciente is null or trim(p_paciente) = '' then
    raise exception 'Informe o nome do paciente.';
  end if;
  if p_tipo_trabalho is null or trim(p_tipo_trabalho) = '' then
    raise exception 'Informe o tipo de trabalho.';
  end if;
  if p_dentes is null or array_length(p_dentes, 1) is null then
    raise exception 'Selecione ao menos um dente no odontograma.';
  end if;

  v_descricao := 'Paciente: ' || trim(p_paciente)
    || E'\n\nTipo de trabalho: ' || trim(p_tipo_trabalho)
    || E'\nDentes: ' || array_to_string(p_dentes, ', ')
    || E'\nCor: ' || coalesce(nullif(trim(p_cor), ''), '-')
    || case when coalesce(trim(p_observacoes), '') <> ''
         then E'\n\nObservacoes: ' || trim(p_observacoes)
         else '' end
    || E'\n\n[Anexo de arquivo (STL): upload em breve]';

  insert into ordens_exocad (cliente_reg, descricao, dentes, qtd_elementos, origem, status, aceito_pelo_admin)
  values (v_sessao.reg, v_descricao, p_dentes, array_length(p_dentes, 1), 'portal', 'a_fazer', false)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function editar_caso_cliente(
  p_sessao        text,
  p_caso_id       uuid,
  p_paciente      text,
  p_tipo_trabalho text,
  p_dentes        int[],
  p_cor           text,
  p_observacoes   text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao    portal_sessoes%rowtype;
  v_ordem     ordens_exocad%rowtype;
  v_descricao text;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cliente' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  select * into v_ordem from ordens_exocad
    where id = p_caso_id and cliente_reg = v_sessao.reg and coalesce(excluido, false) = false;
  if v_ordem.id is null then
    raise exception 'Pedido nao encontrado.';
  end if;
  if v_ordem.status <> 'a_fazer' then
    raise exception 'Este pedido ja entrou em producao e nao pode mais ser editado por aqui. Fale com o laboratorio.';
  end if;

  if p_paciente is null or trim(p_paciente) = '' then
    raise exception 'Informe o nome do paciente.';
  end if;
  if p_tipo_trabalho is null or trim(p_tipo_trabalho) = '' then
    raise exception 'Informe o tipo de trabalho.';
  end if;
  if p_dentes is null or array_length(p_dentes, 1) is null then
    raise exception 'Selecione ao menos um dente no odontograma.';
  end if;

  v_descricao := 'Paciente: ' || trim(p_paciente)
    || E'\n\nTipo de trabalho: ' || trim(p_tipo_trabalho)
    || E'\nDentes: ' || array_to_string(p_dentes, ', ')
    || E'\nCor: ' || coalesce(nullif(trim(p_cor), ''), '-')
    || case when coalesce(trim(p_observacoes), '') <> ''
         then E'\n\nObservacoes: ' || trim(p_observacoes)
         else '' end;

  update ordens_exocad
    set descricao     = v_descricao,
        dentes        = p_dentes,
        qtd_elementos = array_length(p_dentes, 1)
    where id = p_caso_id;
end;
$$;

create or replace function obter_caso_cliente(p_sessao text, p_caso_id uuid)
returns table(
  id             uuid,
  paciente       text,
  tipo_trabalho  text,
  dentes         int[],
  cor            text,
  observacoes    text,
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
        nullif(trim(o.descricao), ''),
        '—'
      ) as paciente,
      coalesce(nullif(substring(o.descricao from 'Tipo de trabalho: ([^\n]*)'), ''), '') as tipo_trabalho,
      coalesce(
        o.dentes,
        (
          select array_agg(x::int order by x::int)
          from unnest(string_to_array(coalesce(substring(o.descricao from 'Dentes: ([^\n]*)'), ''), ', ')) as x
          where x ~ '^[0-9]+$'
        )
      ) as dentes,
      nullif(substring(o.descricao from 'Cor: ([^\n]*)'), '-') as cor,
      nullif(trim(substring(o.descricao from 'Observacoes: (.*?)(?:\n\n\[Anexo|$)')), '') as observacoes,
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
    where o.id = p_caso_id
      and o.cliente_reg = v_sessao.reg
      and coalesce(o.excluido, false) = false;
end;
$$;

grant execute on function enviar_caso(text,text,text,int[],text,text) to anon;
grant execute on function editar_caso_cliente(text,uuid,text,text,int[],text,text) to anon;
grant execute on function obter_caso_cliente(text, uuid) to anon;
