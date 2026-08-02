-- ============================================================
-- Ideali Laboratorio - Portal do Cadista
-- Cadista poder corrigir a quantidade de elementos (dentes) do
-- proprio caso, direto no modal de detalhe (abrirDetalheCadista,
-- portal-cadista.html) -- e o mesmo numero que a comissao usa
-- (financeiro do cadista = qtd_elementos * R$15, ver
-- 008_portal_financeiro_cadista.sql), entao se o pedido veio com a
-- quantidade errada (ou sem preencher, ordens_exocad.qtd_elementos
-- nulo) o cadista consegue ajustar sem precisar pedir pro laboratorio
-- editar por fora.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 020_listar_casos_cadista_excluido.sql
-- (ultima versao de listar_casos_cadista) ja ter rodado antes.
--
-- listar_casos_cadista precisa de DROP antes do CREATE porque estou
-- adicionando uma coluna nova na lista de retorno (qtd_elementos) --
-- o Postgres nao deixa trocar isso com CREATE OR REPLACE.
-- ============================================================

drop function if exists listar_casos_cadista(text);

create function listar_casos_cadista(p_sessao text)
returns table(
  id            uuid,
  cliente_nome  text,
  paciente      text,
  tipo_trabalho text,
  descricao     text,
  status        text,
  observacao    text,
  qtd_elementos int,
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
      o.qtd_elementos,
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

-- ── Editar qtd_elementos do proprio caso ───────────────────────
-- Mesmo padrao de seguranca de atualizar_observacao_caso_cadista
-- (009): SECURITY DEFINER, valida a sessao e so deixa editar um caso
-- cujo cadista_reg bate com o reg da sessao validada.

create or replace function atualizar_qtd_elementos_caso_cadista(
  p_sessao       text,
  p_caso_id      uuid,
  p_qtd_elementos int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao portal_sessoes%rowtype;
  v_ordem  ordens_exocad%rowtype;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cadista' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  select * into v_ordem from ordens_exocad
    where id = p_caso_id and cadista_reg = v_sessao.reg;
  if v_ordem.id is null then
    raise exception 'Caso nao encontrado ou nao atribuido a voce.';
  end if;

  if p_qtd_elementos is null or p_qtd_elementos < 1 then
    raise exception 'Quantidade de elementos precisa ser pelo menos 1.';
  end if;

  update ordens_exocad
    set qtd_elementos = p_qtd_elementos
    where id = p_caso_id;
end;
$$;

grant execute on function atualizar_qtd_elementos_caso_cadista(text,uuid,int) to anon;
