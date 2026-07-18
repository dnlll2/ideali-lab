-- ============================================================
-- Ideali Laboratorio - Portal de Clientes/Cadistas
-- Etapa 1: Cadastro, Convite e Aprovacao
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). E seguro rodar de novo depois
-- (tabelas usam IF NOT EXISTS, funcoes usam CREATE OR REPLACE).
--
-- Depois de rodar, pegue a chave "anon public" em
-- Project Settings > API e informe ao Claude para seguir com o
-- front (paginas convite-cliente.html, convite-cadista.html,
-- portal-cliente.html, portal-cadista.html usam essa chave).
-- ============================================================

create extension if not exists pgcrypto;

-- ── Tabelas ──────────────────────────────────────────────────

create table if not exists convites (
  token       text primary key default encode(gen_random_bytes(24), 'hex'),
  tipo        text not null check (tipo in ('cliente','cadista')),
  usado       boolean not null default false,
  criado_em   timestamptz not null default now()
);

create table if not exists clientes_pendentes (
  id            bigint generated always as identity primary key,
  token_convite text references convites(token),
  nome          text not null,
  cpf_cnpj      text,
  cro           text,
  end_str       text,
  bairro        text,
  cidade        text,
  uf            text,
  cep           text,
  tel           text,
  usuario       text not null unique,
  senha_hash    text not null,
  status        text not null default 'pendente' check (status in ('pendente','aprovado','rejeitado')),
  criado_em     timestamptz not null default now()
);

create table if not exists cadistas_pendentes (
  id            bigint generated always as identity primary key,
  token_convite text references convites(token),
  nome          text not null,
  cnpj          text,
  tel           text,
  usuario       text not null unique,
  senha_hash    text not null,
  status        text not null default 'pendente' check (status in ('pendente','aprovado','rejeitado')),
  criado_em     timestamptz not null default now()
);

-- Tabela paralela a cadastro_clientes (ja existente), para cadistas aprovados
create table if not exists cadastro_cadistas (
  cadista_reg bigint generated always as identity primary key,
  nome        text not null,
  cnpj        text,
  tel         text,
  ativo       boolean not null default true,
  criado_em   timestamptz not null default now()
);

-- Credenciais ficam separadas das tabelas de cadastro "de negocio"
-- (cadastro_clientes/cadastro_cadistas) para nunca misturar hash de
-- senha com dados que sao espelhados no array hardcoded de shared.js.
create table if not exists clientes_login (
  cliente_reg int primary key references cadastro_clientes(reg),
  usuario     text not null unique,
  senha_hash  text not null,
  ativo       boolean not null default true
);

create table if not exists cadistas_login (
  cadista_reg bigint primary key references cadastro_cadistas(cadista_reg),
  usuario     text not null unique,
  senha_hash  text not null,
  ativo       boolean not null default true
);

create table if not exists portal_sessoes (
  token     text primary key default encode(gen_random_bytes(24), 'hex'),
  tipo      text not null check (tipo in ('cliente','cadista')),
  reg       bigint not null,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null default now() + interval '30 days'
);

-- ── RLS: habilita e nao cria nenhuma policy ───────────────────
-- Sem policies, nenhuma role que respeita RLS (anon/authenticated)
-- enxerga ou grava nada aqui. So service_role (ja usada nas paginas
-- internas, bypassa RLS) e as funcoes SECURITY DEFINER abaixo
-- (rodam como dono da funcao) conseguem acessar essas tabelas.

alter table convites            enable row level security;
alter table clientes_pendentes  enable row level security;
alter table cadistas_pendentes  enable row level security;
alter table cadastro_cadistas   enable row level security;
alter table clientes_login      enable row level security;
alter table cadistas_login      enable row level security;
alter table portal_sessoes      enable row level security;

revoke all on convites, clientes_pendentes, cadistas_pendentes, cadastro_cadistas,
              clientes_login, cadistas_login, portal_sessoes
  from anon, authenticated;

-- ── Funcoes RPC (SECURITY DEFINER) ────────────────────────────
-- Unico caminho de acesso as tabelas acima para quem usa a chave anon.

create or replace function validar_convite(p_token text)
returns table(tipo text, valido boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_convite convites%rowtype;
begin
  select * into v_convite from convites where token = p_token;
  if v_convite.token is null then
    return query select null::text, false;
  else
    return query select v_convite.tipo, (not v_convite.usado);
  end if;
end;
$$;

create or replace function enviar_cadastro_cliente(
  p_token text, p_nome text, p_cpf_cnpj text, p_cro text,
  p_end text, p_bairro text, p_cidade text, p_uf text, p_cep text, p_tel text,
  p_usuario text, p_senha text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_convite convites%rowtype;
begin
  select * into v_convite from convites where token = p_token and tipo = 'cliente' and usado = false;
  if v_convite.token is null then
    raise exception 'Convite invalido ou ja utilizado';
  end if;
  if exists (select 1 from clientes_pendentes where usuario = p_usuario)
     or exists (select 1 from clientes_login where usuario = p_usuario) then
    raise exception 'Usuario ja esta em uso';
  end if;

  insert into clientes_pendentes
    (token_convite, nome, cpf_cnpj, cro, end_str, bairro, cidade, uf, cep, tel, usuario, senha_hash)
  values
    (p_token, p_nome, p_cpf_cnpj, p_cro, p_end, p_bairro, p_cidade, p_uf, p_cep, p_tel,
     p_usuario, crypt(p_senha, gen_salt('bf')));

  update convites set usado = true where token = p_token;
end;
$$;

create or replace function enviar_cadastro_cadista(
  p_token text, p_nome text, p_cnpj text, p_tel text,
  p_usuario text, p_senha text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_convite convites%rowtype;
begin
  select * into v_convite from convites where token = p_token and tipo = 'cadista' and usado = false;
  if v_convite.token is null then
    raise exception 'Convite invalido ou ja utilizado';
  end if;
  if exists (select 1 from cadistas_pendentes where usuario = p_usuario)
     or exists (select 1 from cadistas_login where usuario = p_usuario) then
    raise exception 'Usuario ja esta em uso';
  end if;

  insert into cadistas_pendentes (token_convite, nome, cnpj, tel, usuario, senha_hash)
  values (p_token, p_nome, p_cnpj, p_tel, p_usuario, crypt(p_senha, gen_salt('bf')));

  update convites set usado = true where token = p_token;
end;
$$;

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

-- ── Grants: so estas 5 funcoes ficam expostas a chave anon ────

grant execute on function validar_convite(text) to anon;
grant execute on function enviar_cadastro_cliente(text,text,text,text,text,text,text,text,text,text,text,text) to anon;
grant execute on function enviar_cadastro_cadista(text,text,text,text,text,text) to anon;
grant execute on function cliente_login(text,text) to anon;
grant execute on function cadista_login(text,text) to anon;
