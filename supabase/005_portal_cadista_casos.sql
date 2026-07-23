-- ============================================================
-- Ideali Laboratorio - Portal do Cadista
-- Etapa 4: Casos atribuidos ao cadista + distribuicao minima.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 001_portal_convites.sql. Seguro rodar de novo (coluna usa
-- ADD COLUMN IF NOT EXISTS, funcoes usam CREATE OR REPLACE).
--
-- cadista_reg em ordens_exocad e o vinculo "oficial" (mesmo padrao
-- de cliente_reg): quem faz a distribuicao e uma pagina interna
-- (ordens-cam.html, usa a chave service_role, que bypassa RLS) com
-- um dropdown simples escrevendo direto nessa coluna. E' um campo
-- separado do cadista_nome/com_cadista ja existente (que e so uma
-- etiqueta de texto livre para controle manual de envio de arquivo
-- e continua funcionando como antes) -- cadista_reg e o que alimenta
-- de verdade o portal-cadista.html.
-- ============================================================

alter table ordens_exocad add column if not exists cadista_reg bigint references cadastro_cadistas(cadista_reg);

-- ── Listar casos atribuidos ao cadista logado ─────────────────

create or replace function listar_casos_cadista(p_sessao text)
returns table(
  id            uuid,
  cliente_nome  text,
  paciente      text,
  tipo_trabalho text,
  descricao     text,
  status        text,
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
      o.created_at
    from ordens_exocad o
    left join cadastro_clientes cc on cc.reg = o.cliente_reg
    where o.cadista_reg = v_sessao.reg
      and coalesce(o.arquivado, false) = false
    order by o.created_at desc;
end;
$$;

-- ── Avancar status do caso (so a_fazer->fazendo e fazendo->finalizado) ──

create or replace function atualizar_status_caso_cadista(
  p_sessao      text,
  p_caso_id     uuid,
  p_novo_status text
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

  if not (
    (v_ordem.status = 'a_fazer' and p_novo_status = 'fazendo') or
    (v_ordem.status = 'fazendo' and p_novo_status = 'finalizado')
  ) then
    raise exception 'Transicao de status invalida.';
  end if;

  update ordens_exocad
    set status = p_novo_status,
        finalizado_at = case when p_novo_status = 'finalizado' then now() else finalizado_at end
    where id = p_caso_id;
end;
$$;

grant execute on function listar_casos_cadista(text) to anon;
grant execute on function atualizar_status_caso_cadista(text,uuid,text) to anon;
