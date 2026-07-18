-- ============================================================
-- Ideali Laboratorio - Fix: ambiguidade de coluna "token" em
-- cliente_login/cadista_login.
--
-- RETURNS TABLE(token text, ...) cria uma variavel de saida
-- chamada "token", que colide com a coluna "token" de
-- portal_sessoes no INSERT ... RETURNING token. A correcao
-- qualifica a coluna com um alias da tabela (RETURNING ps.token).
--
-- Estas mesmas definicoes ja estao embutidas em
-- 001_portal_convites.sql (que foi atualizado). Este arquivo
-- existe soh para reaplicar so essas duas funcoes sem precisar
-- colar o script inteiro de novo. Seguro rodar mais de uma vez.
-- ============================================================

create or replace function cliente_login(p_usuario text, p_senha text)
returns table(token text, cliente_reg int, nome text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_login clientes_login%rowtype;
  v_nome  text;
  v_token text;
begin
  select * into v_login from clientes_login where usuario = p_usuario and ativo = true;
  if v_login.cliente_reg is null or crypt(p_senha, v_login.senha_hash) <> v_login.senha_hash then
    raise exception 'Usuario ou senha invalidos';
  end if;

  select cc.nome into v_nome from cadastro_clientes cc where cc.reg = v_login.cliente_reg;

  insert into portal_sessoes as ps (tipo, reg) values ('cliente', v_login.cliente_reg)
  returning ps.token into v_token;

  return query select v_token, v_login.cliente_reg, v_nome;
end;
$$;

create or replace function cadista_login(p_usuario text, p_senha text)
returns table(token text, cadista_reg bigint, nome text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_login cadistas_login%rowtype;
  v_nome  text;
  v_token text;
begin
  select * into v_login from cadistas_login where usuario = p_usuario and ativo = true;
  if v_login.cadista_reg is null or crypt(p_senha, v_login.senha_hash) <> v_login.senha_hash then
    raise exception 'Usuario ou senha invalidos';
  end if;

  select ca.nome into v_nome from cadastro_cadistas ca where ca.cadista_reg = v_login.cadista_reg;

  insert into portal_sessoes as ps (tipo, reg) values ('cadista', v_login.cadista_reg)
  returning ps.token into v_token;

  return query select v_token, v_login.cadista_reg, v_nome;
end;
$$;
