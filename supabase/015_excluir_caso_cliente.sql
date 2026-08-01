-- ============================================================
-- Ideali Laboratorio - Cliente excluir o proprio pedido (portal)
-- Botao "Excluir" em portal-cliente.html, so pro dono do pedido e so
-- enquanto ele ainda nao entrou em producao.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 004_portal_meus_casos.sql
-- e de 014_excluir_ordem_cam.sql (coluna excluido) ja terem rodado
-- antes.
--
-- Duas travas, nao uma:
-- 1) so exclui pedido com status = 'a_fazer' -- se ja esta "fazendo"
--    ou "finalizado", o cadista/admin ja pode estar mexendo nisso ou
--    ja entrou em relatorio/comissao, entao o cliente nao mexe mais,
--    fala com o laboratorio.
-- 2) reautenticacao de verdade: p_senha e conferida contra o hash em
--    clientes_login de novo (nao basta a sessao/token ja logado) --
--    protege contra alguem que pegue o celular/computador do cliente
--    ja logado e exclua um pedido sem saber a senha.
--
-- Mesmo soft delete usado em ordens-cam.html (excluido=true, nao
-- DELETE de verdade): listar_meus_casos passa a filtrar excluido,
-- senao o pedido "excluido" continuaria aparecendo pro proprio
-- cliente.
-- ============================================================

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
      and coalesce(o.excluido, false) = false
    order by o.created_at desc;
end;
$$;

-- ── Excluir o proprio pedido (reautenticacao com senha) ───────

create or replace function excluir_caso_cliente(
  p_sessao  text,
  p_caso_id uuid,
  p_senha   text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sessao portal_sessoes%rowtype;
  v_login  clientes_login%rowtype;
  v_ordem  ordens_exocad%rowtype;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cliente' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  select * into v_login from clientes_login where cliente_reg = v_sessao.reg and ativo = true;
  if v_login.cliente_reg is null or crypt(p_senha, v_login.senha_hash) <> v_login.senha_hash then
    raise exception 'Senha incorreta.';
  end if;

  select * into v_ordem from ordens_exocad
    where id = p_caso_id and cliente_reg = v_sessao.reg;
  if v_ordem.id is null then
    raise exception 'Pedido nao encontrado.';
  end if;
  if v_ordem.status <> 'a_fazer' then
    raise exception 'Este pedido ja entrou em producao e nao pode mais ser excluido por aqui. Fale com o laboratorio.';
  end if;

  update ordens_exocad set excluido = true where id = p_caso_id;
end;
$$;

grant execute on function listar_meus_casos(text) to anon;
grant execute on function excluir_caso_cliente(text,uuid,text) to anon;
