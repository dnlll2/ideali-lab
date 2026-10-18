-- ============================================================
-- Ideali Laboratorio - 045 Seguranca: login real + regras de acesso (RLS)
-- Aplicada em 17-18/10/2026, depois do incidente da chave service_role
-- publicada em shared.js (ver docs/incidente-2026-10-17.md).
--
-- So ACRESCENTA: tabela ideali_config, coluna user_id, funcoes, policies.
-- Nenhum dado apagado ou renomeado. As unicas coisas removidas sao policies
-- de Storage que davam acesso anonimo (extratos) ou dependiam do JWT secret
-- antigo (casos) -- substituidas pela Edge Function portal-arquivos.
--
-- Papeis (auth.users.raw_app_meta_data.papel):
--   dono  -> acesso completo (exige codigo de 2 etapas se estiver ativado)
--   inove -> so o que pagamentos-inove.html usa
-- Portais do cliente/cadista continuam usando as funcoes SECURITY DEFINER
-- de sempre (sessao propria em portal_sessoes), sem acesso direto a tabelas.
-- ============================================================

-- ── Configuracao: quem e o dono dos dados ─────────────────────
create table if not exists public.ideali_config (
  id        boolean primary key default true check (id),
  dono_id   uuid references auth.users(id),
  criado_em timestamptz not null default now()
);
alter table public.ideali_config enable row level security;
revoke all on public.ideali_config from anon, authenticated;

-- ── Funcoes de apoio das regras ───────────────────────────────
create or replace function public.ideali_papel()
returns text language sql stable set search_path = '' as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'papel', '')
$$;

-- Verificacao em 2 etapas: quem ativou precisa estar no nivel aal2
create or replace function public.ideali_aal_ok()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      or not exists (select 1 from auth.mfa_factors f
                     where f.user_id = auth.uid() and f.status = 'verified')
$$;

create or replace function public.ideali_e_dono()
returns boolean language sql stable set search_path = '' as $$
  select public.ideali_papel() = 'dono' and public.ideali_aal_ok()
$$;

create or replace function public.ideali_e_inove()
returns boolean language sql stable set search_path = '' as $$
  select public.ideali_papel() = 'inove' and public.ideali_aal_ok()
$$;

-- Dono dos dados para o usuario logado (o proprio dono, ou o dono a quem a Inove presta servico)
create or replace function public.ideali_dono_id()
returns uuid language sql stable set search_path = '' as $$
  select case public.ideali_papel()
           when 'dono'  then auth.uid()
           when 'inove' then nullif(auth.jwt() -> 'app_metadata' ->> 'dono_id', '')::uuid
         end
$$;

-- Valor padrao de user_id: usuario logado, ou (funcoes dos portais, sem login) o dono cadastrado
create or replace function public.ideali_dono_atual()
returns uuid language sql stable security definer set search_path = '' as $$
  select coalesce(public.ideali_dono_id(), (select c.dono_id from public.ideali_config c where c.id))
$$;

grant execute on function public.ideali_papel(), public.ideali_aal_ok(), public.ideali_e_dono(),
  public.ideali_e_inove(), public.ideali_dono_id(), public.ideali_dono_atual() to authenticated, anon;

-- ── Dono (user_id) e regras por tabela ────────────────────────
alter table public.cadastro_cadistas add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.cadastro_cadistas set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists cadastro_cadistas_user_id_idx on public.cadastro_cadistas(user_id);
drop policy if exists "dono acessa tudo" on public.cadastro_cadistas;
create policy "dono acessa tudo" on public.cadastro_cadistas for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.cadastro_clientes add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.cadastro_clientes set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists cadastro_clientes_user_id_idx on public.cadastro_clientes(user_id);
drop policy if exists "dono acessa tudo" on public.cadastro_clientes;
create policy "dono acessa tudo" on public.cadastro_clientes for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.cadistas_login add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.cadistas_login set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists cadistas_login_user_id_idx on public.cadistas_login(user_id);
drop policy if exists "dono acessa tudo" on public.cadistas_login;
create policy "dono acessa tudo" on public.cadistas_login for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.cadistas_pendentes add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.cadistas_pendentes set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists cadistas_pendentes_user_id_idx on public.cadistas_pendentes(user_id);
drop policy if exists "dono acessa tudo" on public.cadistas_pendentes;
create policy "dono acessa tudo" on public.cadistas_pendentes for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.clientes_login add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.clientes_login set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists clientes_login_user_id_idx on public.clientes_login(user_id);
drop policy if exists "dono acessa tudo" on public.clientes_login;
create policy "dono acessa tudo" on public.clientes_login for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.clientes_pendentes add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.clientes_pendentes set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists clientes_pendentes_user_id_idx on public.clientes_pendentes(user_id);
drop policy if exists "dono acessa tudo" on public.clientes_pendentes;
create policy "dono acessa tudo" on public.clientes_pendentes for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.comissoes_pagas add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.comissoes_pagas set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists comissoes_pagas_user_id_idx on public.comissoes_pagas(user_id);
drop policy if exists "dono acessa tudo" on public.comissoes_pagas;
create policy "dono acessa tudo" on public.comissoes_pagas for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());
drop policy if exists "inove select" on public.comissoes_pagas;
create policy "inove select" on public.comissoes_pagas for select to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id());

alter table public.config_mes add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.config_mes set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists config_mes_user_id_idx on public.config_mes(user_id);
drop policy if exists "dono acessa tudo" on public.config_mes;
create policy "dono acessa tudo" on public.config_mes for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.controle_mensal add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.controle_mensal set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists controle_mensal_user_id_idx on public.controle_mensal(user_id);
drop policy if exists "dono acessa tudo" on public.controle_mensal;
create policy "dono acessa tudo" on public.controle_mensal for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());
drop policy if exists "inove select" on public.controle_mensal;
create policy "inove select" on public.controle_mensal for select to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id());
drop policy if exists "inove insert" on public.controle_mensal;
create policy "inove insert" on public.controle_mensal for insert to authenticated with check (public.ideali_e_inove() and user_id = public.ideali_dono_id());
drop policy if exists "inove update" on public.controle_mensal;
create policy "inove update" on public.controle_mensal for update to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id()) with check (public.ideali_e_inove() and user_id = public.ideali_dono_id());

alter table public.controle_mensal_historico add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.controle_mensal_historico set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists controle_mensal_historico_user_id_idx on public.controle_mensal_historico(user_id);
drop policy if exists "dono acessa tudo" on public.controle_mensal_historico;
create policy "dono acessa tudo" on public.controle_mensal_historico for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.convites add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.convites set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists convites_user_id_idx on public.convites(user_id);
drop policy if exists "dono acessa tudo" on public.convites;
create policy "dono acessa tudo" on public.convites for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.estudio_clientes add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.estudio_clientes set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists estudio_clientes_user_id_idx on public.estudio_clientes(user_id);
drop policy if exists "dono acessa tudo" on public.estudio_clientes;
create policy "dono acessa tudo" on public.estudio_clientes for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.estudio_pagamentos add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.estudio_pagamentos set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists estudio_pagamentos_user_id_idx on public.estudio_pagamentos(user_id);
drop policy if exists "dono acessa tudo" on public.estudio_pagamentos;
create policy "dono acessa tudo" on public.estudio_pagamentos for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.estudio_pedidos add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.estudio_pedidos set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists estudio_pedidos_user_id_idx on public.estudio_pedidos(user_id);
drop policy if exists "dono acessa tudo" on public.estudio_pedidos;
create policy "dono acessa tudo" on public.estudio_pedidos for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.gastos_entrega add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.gastos_entrega set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists gastos_entrega_user_id_idx on public.gastos_entrega(user_id);
drop policy if exists "dono acessa tudo" on public.gastos_entrega;
create policy "dono acessa tudo" on public.gastos_entrega for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.inove_clientes add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.inove_clientes set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists inove_clientes_user_id_idx on public.inove_clientes(user_id);
drop policy if exists "dono acessa tudo" on public.inove_clientes;
create policy "dono acessa tudo" on public.inove_clientes for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.inove_controle_mensal add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.inove_controle_mensal set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists inove_controle_mensal_user_id_idx on public.inove_controle_mensal(user_id);
drop policy if exists "dono acessa tudo" on public.inove_controle_mensal;
create policy "dono acessa tudo" on public.inove_controle_mensal for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.inove_pedidos add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.inove_pedidos set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists inove_pedidos_user_id_idx on public.inove_pedidos(user_id);
drop policy if exists "dono acessa tudo" on public.inove_pedidos;
create policy "dono acessa tudo" on public.inove_pedidos for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.ordens_exocad add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.ordens_exocad set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists ordens_exocad_user_id_idx on public.ordens_exocad(user_id);
drop policy if exists "dono acessa tudo" on public.ordens_exocad;
create policy "dono acessa tudo" on public.ordens_exocad for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.pagamento_aportes add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.pagamento_aportes set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists pagamento_aportes_user_id_idx on public.pagamento_aportes(user_id);
drop policy if exists "dono acessa tudo" on public.pagamento_aportes;
create policy "dono acessa tudo" on public.pagamento_aportes for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());
drop policy if exists "inove select" on public.pagamento_aportes;
create policy "inove select" on public.pagamento_aportes for select to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id());
drop policy if exists "inove insert" on public.pagamento_aportes;
create policy "inove insert" on public.pagamento_aportes for insert to authenticated with check (public.ideali_e_inove() and user_id = public.ideali_dono_id());
drop policy if exists "inove update" on public.pagamento_aportes;
create policy "inove update" on public.pagamento_aportes for update to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id()) with check (public.ideali_e_inove() and user_id = public.ideali_dono_id());

alter table public.pedidos add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.pedidos set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists pedidos_user_id_idx on public.pedidos(user_id);
drop policy if exists "dono acessa tudo" on public.pedidos;
create policy "dono acessa tudo" on public.pedidos for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());
drop policy if exists "inove select" on public.pedidos;
create policy "inove select" on public.pedidos for select to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id());

alter table public.tabela_precos add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.tabela_precos set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists tabela_precos_user_id_idx on public.tabela_precos(user_id);
drop policy if exists "dono acessa tudo" on public.tabela_precos;
create policy "dono acessa tudo" on public.tabela_precos for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.tarefas add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.tarefas set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists tarefas_user_id_idx on public.tarefas(user_id);
drop policy if exists "dono acessa tudo" on public.tarefas;
create policy "dono acessa tudo" on public.tarefas for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());

alter table public.vencimento_mensal add column if not exists user_id uuid references auth.users(id) default public.ideali_dono_atual();
update public.vencimento_mensal set user_id = (select dono_id from public.ideali_config where id) where user_id is null;
create index if not exists vencimento_mensal_user_id_idx on public.vencimento_mensal(user_id);
drop policy if exists "dono acessa tudo" on public.vencimento_mensal;
create policy "dono acessa tudo" on public.vencimento_mensal for all to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid())
  with check (public.ideali_e_dono() and user_id = auth.uid());
drop policy if exists "inove select" on public.vencimento_mensal;
create policy "inove select" on public.vencimento_mensal for select to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id());
drop policy if exists "inove insert" on public.vencimento_mensal;
create policy "inove insert" on public.vencimento_mensal for insert to authenticated with check (public.ideali_e_inove() and user_id = public.ideali_dono_id());
drop policy if exists "inove update" on public.vencimento_mensal;
create policy "inove update" on public.vencimento_mensal for update to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id()) with check (public.ideali_e_inove() and user_id = public.ideali_dono_id());
drop policy if exists "inove delete" on public.vencimento_mensal;
create policy "inove delete" on public.vencimento_mensal for delete to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id());

-- portal_sessoes: so as funcoes dos portais mexem (sem policy de proposito)

-- ── Ninguem anonimo acessa tabela direto (portais usam funcoes) ──
revoke all on all tables in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;

-- ── Historico de controle_mensal: gravado pelo gatilho com permissao propria ──
alter function public.log_controle_mensal_changes() security definer;
alter function public.log_controle_mensal_changes() set search_path = public;

-- ── Funcoes administrativas: so com login (antes: qualquer um com a chave publica) ──
CREATE OR REPLACE FUNCTION public.pagar_comissao(p_mes integer, p_ano integer, p_valor_total numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_total     numeric(10,2) := 0;
  v_detalhes  jsonb := '[]'::jsonb;
  v_row       record;
  v_pendente  numeric(10,2);
  v_novo_id   uuid;
  v_final     numeric(10,2);
begin
  if not (public.ideali_e_dono() or public.ideali_e_inove()) then
    raise exception 'Sem permissao.';
  end if;
  for v_row in
    select id, cliente_reg, valor_pago, valor_pago_comissionado
    from controle_mensal
    where mes = p_mes and ano = p_ano
      and valor_pago > valor_pago_comissionado
    order by cliente_reg
    for update
  loop
    v_pendente := round((v_row.valor_pago - v_row.valor_pago_comissionado) * 0.15, 2);
    if v_pendente > 0 then
      update controle_mensal
        set valor_pago_comissionado = v_row.valor_pago,
            updated_at = now()
        where id = v_row.id;

      v_total := v_total + v_pendente;
      v_detalhes := v_detalhes || jsonb_build_object(
        'cliente_reg', v_row.cliente_reg,
        'valor_pago', v_row.valor_pago,
        'valor_pago_comissionado_anterior', v_row.valor_pago_comissionado,
        'valor_base_comissao', v_row.valor_pago - v_row.valor_pago_comissionado,
        'comissao', v_pendente
      );
    end if;
  end loop;

  if v_total <= 0 then
    return jsonb_build_object('ok', false, 'motivo', 'sem_comissao_pendente');
  end if;

  v_final := coalesce(p_valor_total, v_total);

  insert into comissoes_pagas (mes, ano, valor_total, valor_calculado, detalhes_json)
  values (p_mes, p_ano, v_final, v_total, v_detalhes)
  returning id into v_novo_id;

  return jsonb_build_object('ok', true, 'id', v_novo_id, 'valor_total', v_final, 'valor_calculado', v_total, 'detalhes', v_detalhes);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.excluir_comissao_paga(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row comissoes_pagas%rowtype;
  v_det jsonb;
begin
  if not (public.ideali_e_dono() or public.ideali_e_inove()) then
    raise exception 'Sem permissao.';
  end if;
  select * into v_row from comissoes_pagas where id = p_id for update;
  if v_row.id is null then
    return jsonb_build_object('ok', false, 'motivo', 'nao_encontrado');
  end if;
  if exists (
    select 1 from comissoes_pagas
    where mes = v_row.mes and ano = v_row.ano and data_pagamento > v_row.data_pagamento
  ) then
    return jsonb_build_object('ok', false, 'motivo', 'nao_e_o_mais_recente');
  end if;
  for v_det in select * from jsonb_array_elements(v_row.detalhes_json)
  loop
    update controle_mensal
      set valor_pago_comissionado = (v_det->>'valor_pago_comissionado_anterior')::numeric,
          updated_at = now()
      where cliente_reg = (v_det->>'cliente_reg')::int
        and mes = v_row.mes
        and ano = v_row.ano;
  end loop;
  delete from comissoes_pagas where id = p_id;
  return jsonb_build_object('ok', true, 'valor_total', v_row.valor_total, 'mes', v_row.mes, 'ano', v_row.ano);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.admin_gerar_sessao_cliente(p_cliente_reg integer)
 RETURNS TABLE(token text, cliente_reg integer, nome text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_nome  text;
  v_token text;
begin
  if not public.ideali_e_dono() then
    raise exception 'Sem permissao.';
  end if;
  if not exists (select 1 from clientes_login cl where cl.cliente_reg = p_cliente_reg and cl.ativo = true) then
    raise exception 'Cliente nao encontrado ou sem login ativo no portal.';
  end if;
  select cc.nome into v_nome from cadastro_clientes cc where cc.reg = p_cliente_reg;
  insert into portal_sessoes as ps (tipo, reg, expira_em)
    values ('cliente', p_cliente_reg, now() + interval '3 hours')
  returning ps.token into v_token;
  return query select v_token, p_cliente_reg, v_nome;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.admin_gerar_sessao_cadista(p_cadista_reg bigint)
 RETURNS TABLE(token text, cadista_reg bigint, nome text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_nome  text;
  v_token text;
begin
  if not public.ideali_e_dono() then
    raise exception 'Sem permissao.';
  end if;
  if not exists (select 1 from cadistas_login cl where cl.cadista_reg = p_cadista_reg and cl.ativo = true) then
    raise exception 'Cadista nao encontrado ou sem login ativo no portal.';
  end if;
  select ca.nome into v_nome from cadastro_cadistas ca where ca.cadista_reg = p_cadista_reg;
  insert into portal_sessoes as ps (tipo, reg, expira_em)
    values ('cadista', p_cadista_reg, now() + interval '3 hours')
  returning ps.token into v_token;
  return query select v_token, p_cadista_reg, v_nome;
end;
$function$
;

revoke execute on function public.pagar_comissao(integer, integer, numeric) from public, anon;
revoke execute on function public.excluir_comissao_paga(uuid) from public, anon;
grant  execute on function public.pagar_comissao(integer, integer, numeric) to authenticated;
grant  execute on function public.excluir_comissao_paga(uuid) to authenticated;
revoke execute on function public.admin_gerar_sessao_cliente(integer) from public, anon;
revoke execute on function public.admin_gerar_sessao_cadista(bigint) from public, anon;
grant  execute on function public.admin_gerar_sessao_cliente(integer) to authenticated;
grant  execute on function public.admin_gerar_sessao_cadista(bigint) to authenticated;
-- Rotina automatica (pg_cron roda como postgres): ninguem de fora precisa chamar
revoke execute on function public.arquivar_ordens_finalizadas_antigas() from public, anon, authenticated;
-- JWT caseiro dos portais: substituido pela Edge Function portal-arquivos
revoke execute on function public.gerar_jwt_upload(text) from public, anon, authenticated;
revoke execute on function public.gerar_jwt_leitura_cadista(text, uuid) from public, anon, authenticated;

-- ── Lista de clientes para a Inove: so nome e endereco (sem CPF, telefone, e-mail) ──
create or replace function public.inove_listar_clientes()
returns table(reg integer, nome text, end_str text, bairro text, cidade text, uf text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.ideali_e_dono() or public.ideali_e_inove()) then
    raise exception 'Sem permissao.';
  end if;
  return query
    select c.reg::integer, c.nome::text, c.end_str::text, c.bairro::text, c.cidade::text, c.uf::text
    from cadastro_clientes c
    where c.user_id = public.ideali_dono_id();
end;
$$;
revoke execute on function public.inove_listar_clientes() from public, anon;
grant  execute on function public.inove_listar_clientes() to authenticated;

-- ── Storage: os 3 buckets privados, so com login (links assinados) ──
update storage.buckets set public = false where id in ('casos', 'comprovantes', 'extratos');

drop policy if exists "extratos - anon gerencia" on storage.objects;
drop policy if exists "extratos - leitura publica" on storage.objects;
drop policy if exists "cliente insere STL na propria pasta" on storage.objects;
drop policy if exists "cliente le arquivos da propria pasta" on storage.objects;
drop policy if exists "cliente exclui arquivo da propria pasta" on storage.objects;

drop policy if exists "dono gerencia arquivos" on storage.objects;
create policy "dono gerencia arquivos" on storage.objects for all to authenticated
  using (bucket_id in ('casos', 'comprovantes', 'extratos') and public.ideali_e_dono())
  with check (bucket_id in ('casos', 'comprovantes', 'extratos') and public.ideali_e_dono());

drop policy if exists "inove le comprovantes e extratos" on storage.objects;
create policy "inove le comprovantes e extratos" on storage.objects for select to authenticated
  using (bucket_id in ('comprovantes', 'extratos') and public.ideali_e_inove());

drop policy if exists "inove envia comprovante" on storage.objects;
create policy "inove envia comprovante" on storage.objects for insert to authenticated
  with check (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'aportes' and public.ideali_e_inove());

drop policy if exists "inove substitui comprovante" on storage.objects;
create policy "inove substitui comprovante" on storage.objects for update to authenticated
  using (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'aportes' and public.ideali_e_inove())
  with check (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'aportes' and public.ideali_e_inove());
