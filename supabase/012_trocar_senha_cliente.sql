-- ============================================================
-- Ideali Laboratorio - Trocar senha obrigatoria no primeiro acesso
-- Cliente com login criado direto (fora do fluxo de convite, ex:
-- Kleber Luander / reg 27) entra com uma senha temporaria definida
-- pelo admin e e obrigado a trocar antes de usar o portal.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 001_portal_convites.sql
-- ja ter rodado antes (recria cliente_login de la, so acrescentando
-- deve_trocar_senha no retorno).
-- ============================================================

alter table clientes_login add column if not exists deve_trocar_senha boolean not null default false;

-- Kleber Luander (reg 27): login criado direto pelo admin com senha
-- temporaria, precisa trocar no primeiro acesso.
update clientes_login set deve_trocar_senha = true where cliente_reg = 27;

-- ── cliente_login: mesma funcao de 001/002, so acrescentando
-- deve_trocar_senha no retorno (o front decide se trava a tela).
-- Precisa de DROP antes: mudar as colunas de saida (OUT params) de
-- uma funcao existente nao e permitido via CREATE OR REPLACE.
drop function if exists cliente_login(text,text);

create or replace function cliente_login(p_usuario text, p_senha text)
returns table(token text, cliente_reg int, nome text, deve_trocar_senha boolean)
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

  return query select v_token, v_login.cliente_reg, v_nome, v_login.deve_trocar_senha;
end;
$$;

-- ── Trocar a propria senha (sessao ja logada) ─────────────────

create or replace function trocar_senha_cliente(p_sessao text, p_senha_nova text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sessao portal_sessoes%rowtype;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cliente' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  if p_senha_nova is null or length(p_senha_nova) < 6 then
    raise exception 'A nova senha precisa ter ao menos 6 caracteres.';
  end if;

  update clientes_login
    set senha_hash = crypt(p_senha_nova, gen_salt('bf')),
        deve_trocar_senha = false
    where cliente_reg = v_sessao.reg;
end;
$$;

grant execute on function cliente_login(text,text) to anon;
grant execute on function trocar_senha_cliente(text,text) to anon;
