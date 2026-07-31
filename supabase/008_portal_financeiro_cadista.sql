-- ============================================================
-- Ideali Laboratorio - Portal do Cadista
-- Etapa 6: Aba "Financeiro" no portal-cadista.html - paga R$15
-- por ELEMENTO dental trabalhado (nao por caso).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 003_portal_caso.sql e 005_portal_cadista_casos.sql. Seguro rodar
-- de novo (ADD COLUMN IF NOT EXISTS, funcoes usam CREATE OR REPLACE).
--
-- Por que um campo novo (qtd_elementos) em vez de so contar a
-- descricao em texto livre: ordens_exocad nunca teve um numero
-- estruturado de elementos por caso (so a coluna "descricao" solta).
-- Da pra extrair via regex quando o caso veio do portal-cliente
-- (que grava "Dentes: 13, 11, 21" na descricao), mas a maioria dos
-- casos hoje e cadastrada manualmente em ordens-cam.html, sem esse
-- padrao -- contar de forma exata exige o campo. Casos antigos (sem
-- qtd_elementos) nao entram no financeiro; combinado que isso so
-- precisa valer daqui pra frente.
--
-- Quem preenche qtd_elementos:
-- - enviar_caso (portal-cliente): automatico, = numero de dentes
--   escolhidos no odontograma.
-- - ordens-cam.html: campo "Qtd. elementos" no modal de Nova Ordem
--   (padrao 1) e um badge editavel em cada card (🦷 N), igual o
--   badge de Observacao ja existente.
-- ============================================================

alter table ordens_exocad add column if not exists qtd_elementos int;

-- ── enviar_caso: agora grava qtd_elementos = numero de dentes ──

create or replace function enviar_caso(
  p_sessao       text,
  p_paciente     text,
  p_tipo_trabalho text,
  p_dentes       int[],
  p_cor          text,
  p_observacoes  text
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

  insert into ordens_exocad (cliente_reg, descricao, origem, status, qtd_elementos)
  values (v_sessao.reg, v_descricao, 'portal', 'a_fazer', array_length(p_dentes, 1))
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function enviar_caso(text,text,text,int[],text,text) to anon;

-- ── Financeiro do cadista: mes a mes, casos finalizados + valor ──
-- (R$15 por elemento; qtd_elementos ausente conta como 1 elemento,
-- so como salvaguarda -- na pratica todo caso novo ja vem com o
-- campo preenchido, seja pelo portal-cliente ou pelo ordens-cam.html)

create or replace function listar_financeiro_cadista(p_sessao text)
returns table(
  mes           int,
  ano           int,
  qtd_casos     int,
  qtd_elementos int,
  valor         numeric
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
      extract(month from o.finalizado_at)::int as mes,
      extract(year from o.finalizado_at)::int as ano,
      count(*)::int as qtd_casos,
      sum(coalesce(o.qtd_elementos, 1))::int as qtd_elementos,
      (sum(coalesce(o.qtd_elementos, 1)) * 15)::numeric as valor
    from ordens_exocad o
    where o.cadista_reg = v_sessao.reg
      and o.status = 'finalizado'
      and o.finalizado_at is not null
    group by 1, 2
    order by ano desc, mes desc
    limit 12;
end;
$$;

grant execute on function listar_financeiro_cadista(text) to anon;
