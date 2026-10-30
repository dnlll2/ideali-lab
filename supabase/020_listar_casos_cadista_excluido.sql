-- ============================================================
-- Ideali Laboratorio - Corrige listar_casos_cadista pra nao mostrar
-- casos excluidos (soft delete) no portal-cadista.html.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 009_portal_cadista_abas_observacao.sql
-- e 014_excluir_ordem_cam.sql (coluna excluido) ja terem rodado antes.
--
-- Mesmo bug ja corrigido em listar_meus_casos (015_excluir_caso_cliente.sql):
-- a funcao filtrava arquivado=false mas esquecia de filtrar excluido=false,
-- entao um caso excluido no ordens-cam.html (ex: "Joao teste") sumia de la
-- mas continuava aparecendo no painel do cadista dono do caso.
--
-- So adiciona a condicao no WHERE -- lista de colunas de retorno nao muda,
-- entao CREATE OR REPLACE funciona (nao precisa DROP FUNCTION como em 009).
-- ============================================================

create or replace function listar_casos_cadista(p_sessao text)
returns table(
  id            uuid,
  cliente_nome  text,
  paciente      text,
  tipo_trabalho text,
  descricao     text,
  status        text,
  observacao    text,
  criado_em     timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao portal_sessoes%rowtype;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cadista' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  return query
    select
      o.id,
      coalesce(o.cliente_nome, cc.nome, '—') as cliente_nome,
      coalesce(
        nullif(substring(o.descricao from 'Paciente: ([^\n]*)'), ''),
        nullif(substring(o.descricao from '^Pac\s+(.+?)\s+-\s+'), '')
      ) as paciente,
      nullif(substring(o.descricao from 'Tipo de trabalho: ([^\n]*)'), '') as tipo_trabalho,
      o.descricao,
      o.status,
      o.observacao,
      o.created_at
    from ordens_exocad o
    left join cadastro_clientes cc on cc.reg = o.cliente_reg
    where o.cadista_reg = v_sessao.reg
      and coalesce(o.arquivado, false) = false
      and coalesce(o.excluido, false) = false
    order by o.created_at desc;
end;
$$;

grant execute on function listar_casos_cadista(text) to anon;
