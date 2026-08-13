-- ============================================================
-- Ideali Laboratorio - Portal do Cadista
-- Etapa 9: Badge "Aguardando aprovacao" no card do cadista.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 009_portal_cadista_abas_observacao.sql. Seguro rodar de novo
-- (listar_casos_cadista precisa de DROP antes do CREATE, mesmo
-- motivo da etapa 7: Postgres nao deixa mudar a lista de colunas
-- de retorno com CREATE OR REPLACE).
--
-- Nao e um 4o status: e a mesma coluna booleana "aprovacao" que
-- ordens-cam.html ja usa (badge "⏳ Aprovação"), reaproveitada aqui
-- em vez de virar um novo campo paralelo -- fica refletida nos dois
-- lados, e continua ortogonal ao status (a_fazer/fazendo/finalizado),
-- podendo ligar/desligar em qualquer coluna do kanban.
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
  aprovacao     boolean,
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
      coalesce(o.aprovacao, false) as aprovacao,
      o.created_at
    from ordens_exocad o
    left join cadastro_clientes cc on cc.reg = o.cliente_reg
    where o.cadista_reg = v_sessao.reg
      and coalesce(o.arquivado, false) = false
    order by o.created_at desc;
end;
$$;

grant execute on function listar_casos_cadista(text) to anon;

-- ── Ligar/desligar "aguardando aprovacao" no proprio caso ──────

create or replace function atualizar_aprovacao_caso_cadista(
  p_sessao      text,
  p_caso_id     uuid,
  p_aprovacao   boolean
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

  update ordens_exocad
    set aprovacao = p_aprovacao
    where id = p_caso_id;
end;
$$;

grant execute on function atualizar_aprovacao_caso_cadista(text,uuid,boolean) to anon;
