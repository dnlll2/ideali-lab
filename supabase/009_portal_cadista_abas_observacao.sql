-- ============================================================
-- Ideali Laboratorio - Portal do Cadista
-- Etapa 7: Abas por status (A Fazer / Fazendo / Finalizado) com
-- contador, e observacao editavel pelo cadista em cada caso.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 005_portal_cadista_casos.sql. Seguro rodar de novo (a funcao
-- listar_casos_cadista precisa de DROP antes do CREATE porque o
-- Postgres nao deixa trocar a lista de colunas de retorno com
-- CREATE OR REPLACE; atualizar_observacao_caso_cadista usa
-- CREATE OR REPLACE normalmente).
--
-- observacao e a mesma coluna que ordens-cam.html ja le/escreve
-- (o badge "📝 Obs." do painel interno) -- nao e um campo paralelo,
-- entao o que o cadista escreve aqui aparece direto pro time interno
-- e vice-versa.
--
-- Mesmo padrao de seguranca de atualizar_status_caso_cadista: a
-- funcao e SECURITY DEFINER, valida a sessao (portal_sessoes) e so
-- deixa editar um caso cujo cadista_reg bate com o reg da sessao
-- validada -- um cadista nunca escreve observacao no caso de outro.
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
    order by o.created_at desc;
end;
$$;

grant execute on function listar_casos_cadista(text) to anon;

-- ── Editar observacao do proprio caso ──────────────────────────

create or replace function atualizar_observacao_caso_cadista(
  p_sessao      text,
  p_caso_id     uuid,
  p_observacao  text
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
    set observacao = nullif(trim(p_observacao), '')
    where id = p_caso_id;
end;
$$;

grant execute on function atualizar_observacao_caso_cadista(text,uuid,text) to anon;
