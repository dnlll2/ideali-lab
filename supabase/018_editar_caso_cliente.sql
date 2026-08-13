-- ============================================================
-- Ideali Laboratorio - Portal de Clientes
-- Etapa 8: Cliente ver detalhe / editar / anexar mais arquivos no
-- proprio pedido, direto pelo card em "Pedidos em Andamento" (antes
-- os cards nao eram clicaveis).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 004_portal_meus_casos.sql e 016_upload_stl_jwt.sql.
--
-- Mesma trava de sempre (igual excluir_caso_cliente, 015): so edita
-- pedido com status = 'a_fazer' -- se ja esta "fazendo" ou
-- "finalizado", o cadista pode ja estar mexendo nisso ou ja
-- finalizou, entao o cliente nao mexe mais por aqui, fala com o
-- laboratorio. "Anexar mais arquivos" segue a mesma trava (nao so
-- editar texto).
--
-- ordens_exocad nao tem colunas estruturadas pra paciente/dentes/
-- cor/observacoes -- tudo fica dentro de "descricao" (texto livre
-- montado por enviar_caso, 003/008/013). obter_caso_cliente faz o
-- parse inverso pra devolver os campos separados pro form de edicao;
-- editar_caso_cliente remonta a descricao no mesmo formato.
-- ============================================================

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
      (
        select array_agg(x::int order by x::int)
        from unnest(string_to_array(coalesce(substring(o.descricao from 'Dentes: ([^\n]*)'), ''), ', ')) as x
        where x ~ '^[0-9]+$'
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

grant execute on function obter_caso_cliente(text, uuid) to anon;

-- ── Editar pedido (so status='a_fazer', so o dono) ────────────────

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
        qtd_elementos = array_length(p_dentes, 1)
    where id = p_caso_id;
end;
$$;

grant execute on function editar_caso_cliente(text, uuid, text, text, int[], text, text) to anon;

-- ── Listar anexos ja enviados (so pra montar a tela de edicao) ────
-- Mesmo esquema do bucket privado "casos" de 016_upload_stl_jwt.sql:
-- so tinha policy de INSERT pro JWT temporario (gerar_jwt_upload).
-- Sem policy de SELECT o cliente nunca conseguia listar o que ja
-- tinha enviado. Mesma trava: o claim cliente_reg do JWT tem que
-- bater com o 1o segmento do path -- a chave anon "de verdade" (sem
-- esse JWT) nao tem claim nenhum, entao nunca bate.

drop policy if exists "cliente le arquivos da propria pasta" on storage.objects;
create policy "cliente le arquivos da propria pasta"
on storage.objects for select
to anon
using (
  bucket_id = 'casos'
  and (storage.foldername(name))[1] = (auth.jwt() ->> 'cliente_reg')
);
