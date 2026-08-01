-- ============================================================
-- Ideali Laboratorio - Admin: "Ver como" (visualizar o portal do
-- cliente/cadista sem saber a senha dele)
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 001_portal_convites.sql. Seguro rodar de novo (funcoes usam
-- CREATE OR REPLACE, revokes/grants sao idempotentes).
--
-- IMPORTANTE (achado durante a implementacao, em duas partes):
--
-- 1) Toda funcao nova no Postgres recebe EXECUTE para PUBLIC por
--    padrao, e anon herda isso de PUBLIC. "Nao dar grant pra anon"
--    NAO basta -- precisa REVOKE EXECUTE ... FROM PUBLIC explicito.
--
-- 2) Alem disso, a Supabase roda (no provisionamento do projeto)
--    algo equivalente a
--      ALTER DEFAULT PRIVILEGES IN SCHEMA public
--        GRANT ALL ON FUNCTIONS TO anon, authenticated;
--    o que significa que toda funcao nova ja nasce com um GRANT
--    PROPRIO (nao so herdado de PUBLIC) para anon/authenticated.
--    Revogar so de PUBLIC nao remove esse grant especifico -- e'
--    preciso revogar de anon e authenticated tambem, nomeados.
--
-- Confirmamos os dois comportamentos ao vivo: business_days_add
-- (Etapa 3, nunca teve "grant to anon") respondia normalmente pra
-- chave anon mesmo depois do primeiro REVOKE ... FROM PUBLIC; so
-- parou quando revogamos de anon/authenticated tambem.
--
-- Regra pra qualquer funcao interna daqui pra frente: se ela NAO
-- deve ser chamavel pela chave anon, termina sempre com
--   revoke execute on function ... from public, anon, authenticated;
-- Nunca confiar na ausencia de "grant to anon" sozinha.
--
-- Sessao gerada por estas funcoes expira em 3h (bem mais curto que
-- os 30 dias de um login normal), para limitar o estrago se o link
-- vazar (fica na URL da aba nova / historico do navegador).
-- ============================================================

revoke execute on function business_days_add(date, int) from public, anon, authenticated;

create or replace function admin_gerar_sessao_cliente(p_cliente_reg int)
returns table(token text, cliente_reg int, nome text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome  text;
  v_token text;
begin
  if not exists (select 1 from clientes_login cl where cl.cliente_reg = p_cliente_reg and cl.ativo = true) then
    raise exception 'Cliente nao encontrado ou sem login ativo no portal.';
  end if;

  select cc.nome into v_nome from cadastro_clientes cc where cc.reg = p_cliente_reg;

  insert into portal_sessoes as ps (tipo, reg, expira_em)
    values ('cliente', p_cliente_reg, now() + interval '3 hours')
  returning ps.token into v_token;

  return query select v_token, p_cliente_reg, v_nome;
end;
$$;

create or replace function admin_gerar_sessao_cadista(p_cadista_reg bigint)
returns table(token text, cadista_reg bigint, nome text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome  text;
  v_token text;
begin
  if not exists (select 1 from cadistas_login cl where cl.cadista_reg = p_cadista_reg and cl.ativo = true) then
    raise exception 'Cadista nao encontrado ou sem login ativo no portal.';
  end if;

  select ca.nome into v_nome from cadastro_cadistas ca where ca.cadista_reg = p_cadista_reg;

  insert into portal_sessoes as ps (tipo, reg, expira_em)
    values ('cadista', p_cadista_reg, now() + interval '3 hours')
  returning ps.token into v_token;

  return query select v_token, p_cadista_reg, v_nome;
end;
$$;

revoke execute on function admin_gerar_sessao_cliente(int)    from public, anon, authenticated;
revoke execute on function admin_gerar_sessao_cadista(bigint) from public, anon, authenticated;
grant  execute on function admin_gerar_sessao_cliente(int)    to service_role;
grant  execute on function admin_gerar_sessao_cadista(bigint) to service_role;
