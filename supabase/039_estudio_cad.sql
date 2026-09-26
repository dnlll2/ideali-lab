-- ============================================================
-- Ideali Laboratorio - Estudio CAD
-- Sistema separado pra desenhos CAD avulsos (fora do fluxo Inove).
-- Tabelas proprias: NAO referenciam cadastro_clientes, ordens_exocad
-- nem controle_mensal -- nada daqui entra no financeiro do laboratorio.
-- Arquivos vao pro bucket 'casos' com prefixo 'estudio/<pedido_id>/'.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

create table if not exists estudio_clientes (
  id              uuid primary key default gen_random_uuid(),
  nome            text not null,
  telefone        text,
  email           text,
  documento       text,          -- CPF/CNPJ, opcional
  cidade          text,
  preco_elemento  numeric(10,2), -- preco padrao por elemento, pre-preenche o pedido
  observacao      text,
  ativo           boolean not null default true,
  created_at      timestamptz not null default now()
);

create table if not exists estudio_pedidos (
  id              uuid primary key default gen_random_uuid(),
  numero          bigint generated always as identity,
  cliente_id      uuid not null references estudio_clientes(id),
  paciente        text,
  tipo_trabalho   text,
  material        text,
  dentes          int[],
  qtd_elementos   integer,
  prazo           date,
  valor           numeric(10,2) not null default 0,
  pago            boolean not null default false,
  pago_em         date,
  status          text not null default 'a_fazer'
                  check (status in ('a_fazer','fazendo','finalizado')),
  observacao      text,
  arquivado       boolean not null default false,
  created_at      timestamptz not null default now(),
  finalizado_at   timestamptz
);

create index if not exists estudio_pedidos_cliente_idx on estudio_pedidos(cliente_id);
create index if not exists estudio_pedidos_status_idx  on estudio_pedidos(status) where not arquivado;

-- Mesmo esquema das outras tabelas: RLS ligado e sem policies, entao
-- so a service_role (usada pelo shared.js) le/escreve.
alter table estudio_clientes enable row level security;
alter table estudio_pedidos  enable row level security;
