-- ============================================================
-- Ideali Laboratorio - 052 Inove: so acompanhamento (view limitada)
--
-- Pedido do dono em 29/10/2026 (itens 6 e 5):
--   A Inove ve os clientes ATIVOS e os INATIVOS COM SALDO diferente de zero (devendo
--   ou com credito); inativo zerado some. De cada um, so: nome, telefone (para o botao WhatsApp),
--   saldo em aberto/credito e o que ja via no controle mensal (valor do mes,
--   valor pago, recebido, conferido) e nos pagamentos/comprovantes.
--   NUNCA: CPF, endereco, valor dos pedidos, gastos, tarefas, cadistas,
--   comissao (inclusive valor_pago_comissionado), Valuation.
--   Continua fazendo o que ja faz: marcar "recebido", "conferido pela Inove" e
--   registrar pagamento com comprovante (travas da 049 continuam valendo).
--
-- O que muda:
--   1. Tira TODA politica de leitura/escrita "inove..." das tabelas do schema public,
--      menos pagamento_aportes e vencimento_mensal (pagamentos dela e vencimento).
--      As politicas tiradas ficam guardadas em ideali_politicas_guardadas
--      (o 052_desfazer.sql recria exatamente como estavam).
--   2. Views (rodam como dono da view, com filtro de papel embutido):
--        inove_clientes_v        reg, nome, tel_wa, ativo, saldo, credito, vencimento mais antigo, dias de atraso
--                                (ativos + inativos com saldo <> 0)
--        inove_controle_mensal_v controle_mensal SEM valor_pago_comissionado e extrato_url
--                                (extrato_path so aparece se o dono liberar o PDF)
--        inove_config_v          frase do WhatsApp e se o PDF do extrato esta liberado
--   3. Funcoes para o que a Inove grava (recebido / conferido), contagem de pedidos
--      pendentes SEM valor, e registro de cada clique no botao WhatsApp.
--   4. cadastro_clientes.tel_wa: telefone so com digitos e 55 na frente (calculado
--      a partir de "tel"; nada do que esta gravado muda). Mudanca de telefone vai
--      para fin_auditoria (so o telefone, sem copiar CPF/endereco) e pode ser desfeita.
--   5. Storage: Inove le comprovantes; extratos (PDF) so se fin_config.inove_ve_extrato_pdf
--      (padrao: NAO, ate o dono confirmar se os valores do PDF sao precos da Inove).
--      Arquivos dos casos (STL): nao le mais.
--
-- NAO altera nenhum valor gravado. Precisa da 051 aplicada antes (para de
-- rodar com mensagem se nao estiver). Seguro rodar de novo.
-- Desfazer: supabase/052_desfazer.sql
-- Meses: mes e 0-indexado (0 = janeiro), igual ao resto do sistema.
-- ============================================================

begin;

-- ── 0) Confere se a 051 esta aplicada ─────────────────────────
do $$
begin
  if to_regclass('public.fin_config') is null
     or to_regclass('public.saldo_abertura_clientes') is null
     or to_regclass('public.fin_auditoria') is null then
    raise exception '052 PARADA: a migracao 051 (Central do Financeiro) ainda nao foi aplicada. Faca o backup, rode 051_central_financeiro_extratos.sql e depois rode esta 052 de novo. Nada foi alterado.';
  end if;
end $$;

-- ── 1) Guarda das politicas que vao sair (para o desfazer) ────
create table if not exists public.ideali_politicas_guardadas (
  id          bigint generated always as identity primary key,
  migracao    text not null,
  schemaname  text not null,
  tablename   text not null,
  policyname  text not null,
  permissive  text not null,
  roles       text[] not null,
  cmd         text not null,
  qual        text,
  with_check  text,
  guardado_em timestamptz not null default now(),
  unique (migracao, schemaname, tablename, policyname)
);
alter table public.ideali_politicas_guardadas enable row level security;
revoke all on public.ideali_politicas_guardadas from anon, authenticated;

insert into public.ideali_politicas_guardadas (migracao, schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check)
select '052', p.schemaname, p.tablename, p.policyname, p.permissive, p.roles::text[], p.cmd, p.qual, p.with_check
from pg_policies p
where (p.schemaname = 'public' and p.policyname ilike 'inove%'
       and p.tablename not in ('pagamento_aportes', 'vencimento_mensal', 'inove_whatsapp_cliques'))
   or (p.schemaname = 'storage' and p.tablename = 'objects' and p.policyname = 'inove le comprovantes e extratos')
on conflict (migracao, schemaname, tablename, policyname) do nothing;

do $$
declare r record;
begin
  for r in select * from public.ideali_politicas_guardadas where migracao = '052' loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- ── 2) Ajustes novos em fin_config ────────────────────────────
alter table public.fin_config add column if not exists inove_whatsapp_frase text not null
  default 'Olá, {nome}. Aqui é da Inove 3D, sobre seu pagamento/seus trabalhos.';
alter table public.fin_config add column if not exists inove_ve_extrato_pdf boolean not null default false;

-- Leitura do ajuste pela politica do Storage (a Inove nao le fin_config)
create or replace function public.inove_ve_extrato_pdf()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.ideali_e_inove() and coalesce(
    (select f.inove_ve_extrato_pdf from public.fin_config f where f.user_id = public.ideali_dono_id()), false)
$$;
revoke execute on function public.inove_ve_extrato_pdf() from public, anon;
grant  execute on function public.inove_ve_extrato_pdf() to authenticated;

-- ── 3) Storage ────────────────────────────────────────────────
drop policy if exists "inove le comprovantes" on storage.objects;
create policy "inove le comprovantes" on storage.objects for select to authenticated
  using (bucket_id = 'comprovantes' and public.ideali_e_inove());
drop policy if exists "inove le extratos se liberado" on storage.objects;
create policy "inove le extratos se liberado" on storage.objects for select to authenticated
  using (bucket_id = 'extratos' and public.inove_ve_extrato_pdf());

-- ── 4) Telefone para WhatsApp ─────────────────────────────────
-- "(21) 98765-4321", "021 98765 4321", "+55 21 98765-4321" -> "5521987654321".
-- Numero que nao der para entender -> null (o botao fica "sem telefone").
create or replace function public.ideali_tel_wa(p text)
returns text language plpgsql immutable set search_path = '' as $$
declare d text := regexp_replace(coalesce(p, ''), '\D', '', 'g');
begin
  d := ltrim(d, '0');
  if length(d) in (10, 11) then d := '55' || d; end if;
  if length(d) not in (12, 13) or left(d, 2) <> '55' then return null; end if;
  if substr(d, 3, 2)::int < 11 then return null; end if;           -- DDD invalido
  if length(d) = 13 and substr(d, 5, 1) <> '9' then return null; end if;  -- celular com 9 digitos comeca com 9
  return d;
end;
$$;
grant execute on function public.ideali_tel_wa(text) to authenticated;

alter table public.cadastro_clientes add column if not exists tel_wa text
  generated always as (public.ideali_tel_wa(tel)) stored;

-- Historico de mudanca de telefone (so o telefone; nao copia CPF/endereco para a auditoria)
create or replace function public.ideali_auditar_tel()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.tel is not distinct from old.tel then return null; end if;
  insert into fin_auditoria (usuario_id, usuario_email, tabela, registro_id, acao, antes, depois, user_id)
  values (auth.uid(), auth.jwt() ->> 'email', 'cadastro_clientes', new.reg::text,
          case when current_setting('ideali.desfazer', true) = 'on' then 'desfazer telefone' else 'telefone' end,
          jsonb_build_object('reg', old.reg, 'nome', old.nome, 'tel', old.tel),
          jsonb_build_object('reg', new.reg, 'nome', new.nome, 'tel', new.tel),
          new.user_id);
  return null;
end;
$$;
revoke execute on function public.ideali_auditar_tel() from public, anon, authenticated;
drop trigger if exists ideali_auditar_tel on public.cadastro_clientes;
create trigger ideali_auditar_tel after update of tel on public.cadastro_clientes
  for each row execute function public.ideali_auditar_tel();

-- Desfaz a ultima troca de telefone do cliente (volta o valor de antes)
create or replace function public.ideali_desfazer_tel(p_reg int)
returns text language plpgsql security definer set search_path = public as $$
declare v_antes text; v_id bigint;
begin
  if not public.ideali_e_dono() then raise exception 'Sem permissao.'; end if;
  select a.id, a.antes ->> 'tel' into v_id, v_antes
    from fin_auditoria a
   where a.user_id = auth.uid() and a.tabela = 'cadastro_clientes' and a.registro_id = p_reg::text
     and a.acao = 'telefone'
   order by a.id desc limit 1;
  if v_id is null then raise exception 'Nenhuma troca de telefone para desfazer.'; end if;
  perform set_config('ideali.desfazer', 'on', true);
  update cadastro_clientes set tel = v_antes where reg = p_reg and user_id = auth.uid();
  perform set_config('ideali.desfazer', 'off', true);
  update fin_auditoria set acao = 'telefone (desfeito)' where id = v_id;
  return v_antes;
end;
$$;
revoke execute on function public.ideali_desfazer_tel(int) from public, anon;
grant  execute on function public.ideali_desfazer_tel(int) to authenticated;

-- ── 5) Vencimento de um mes: o editado a mao, ou o 5o dia util do mes seguinte ──
-- Mesma regra de pagamentos-inove.html (feriados nacionais fixos + Carnaval, Sexta Santa, Corpus Christi).
create or replace function public.fin_pascoa(p_ano int)
returns date language plpgsql immutable set search_path = '' as $$
declare a int; b int; c int; d int; e int; f int; g int; h int; i int; k int; l int; m int; mes int; dia int;
begin
  a := p_ano % 19; b := p_ano / 100; c := p_ano % 100; d := b / 4; e := b % 4;
  f := (b + 8) / 25; g := (b - f + 1) / 3; h := (19 * a + b - d - g + 15) % 30;
  i := c / 4; k := c % 4; l := (32 + 2 * e + 2 * i - h - k) % 7; m := (a + 11 * h + 22 * l) / 451;
  mes := (h + l - 7 * m + 114) / 31; dia := ((h + l - 7 * m + 114) % 31) + 1;
  return make_date(p_ano, mes, dia);
end;
$$;

create or replace function public.fin_vencimento(p_mes int, p_ano int)
returns date language plpgsql stable security definer set search_path = public as $$
declare
  v_manual date; v_d date; v_n int := 0; v_ano int; v_pasc date; v_fer date[];
begin
  select v.data_vencimento into v_manual from vencimento_mensal v
   where v.mes = p_mes and v.ano = p_ano and v.user_id = public.ideali_dono_atual() limit 1;
  if v_manual is not null then return v_manual; end if;
  v_d := (make_date(p_ano, p_mes + 1, 1) + interval '1 month')::date;
  v_ano := extract(year from v_d)::int;
  v_pasc := public.fin_pascoa(v_ano);
  v_fer := array[make_date(v_ano,1,1), make_date(v_ano,4,21), make_date(v_ano,5,1), make_date(v_ano,9,7),
                 make_date(v_ano,10,12), make_date(v_ano,11,2), make_date(v_ano,11,15), make_date(v_ano,12,25),
                 v_pasc - 47, v_pasc - 2, v_pasc + 60];
  loop
    if extract(isodow from v_d) < 6 and not (v_d = any(v_fer)) then
      v_n := v_n + 1;
      if v_n = 5 then return v_d; end if;
    end if;
    v_d := v_d + 1;
  end loop;
end;
$$;
revoke execute on function public.fin_vencimento(int, int) from public, anon;
grant  execute on function public.fin_vencimento(int, int) to authenticated;

-- ── 6) View de clientes da Inove (e do dono) ──────────────────
-- Saldo = meses desde o inicio do sistema (valor_mes - valor_pago) + saldo de abertura.
--   > 0: cliente deve.  < 0: credito do cliente (pagou a mais).
-- Mes em aberto mais antigo: pagamento abate do mais antigo para o mais novo, entao o
-- que falta pagar esta nos meses mais recentes; anda do mais novo para o mais antigo
-- somando o cobrado ate cobrir o saldo -- o ultimo mes alcancado e o mais antigo em aberto.
drop view if exists public.inove_clientes_v;
create view public.inove_clientes_v with (security_invoker = false) as
with dono as (
  select public.ideali_dono_id() as id
  where public.ideali_e_inove() or public.ideali_e_dono()
),
cfg as (
  select coalesce((select f.data_inicio_sistema from public.fin_config f join dono on f.user_id = dono.id),
                  date '2026-06-14') as inicio
),
cli as (
  select c.reg, c.nome, c.tel_wa, coalesce(c.status, 'ativo') <> 'inativo' as ativo
  from public.cadastro_clientes c join dono on c.user_id = dono.id
),
mov as (
  select m.cliente_reg as reg, coalesce(m.valor_mes, 0) as cobrado, coalesce(m.valor_pago, 0) as pago,
         public.fin_vencimento(m.mes, m.ano) as venc
  from public.controle_mensal m join dono on m.user_id = dono.id, cfg
  where make_date(m.ano, m.mes + 1, 1) >= date_trunc('month', cfg.inicio)::date
  union all
  select a.cliente_reg, greatest(a.valor, 0), greatest(-a.valor, 0), cfg.inicio
  from public.saldo_abertura_clientes a join dono on a.user_id = dono.id, cfg
),
tot as (select reg, round(sum(cobrado - pago), 2) as saldo from mov group by reg),
acum as (
  select reg, venc, cobrado,
         sum(cobrado) over (partition by reg order by venc desc rows between unbounded preceding and current row) as acum
  from mov where cobrado > 0
),
antigo as (
  select a.reg, min(a.venc) as venc
  from acum a join tot t on t.reg = a.reg
  where t.saldo > 0.005 and a.acum - a.cobrado < t.saldo
  group by a.reg
),
hoje as (select (now() at time zone 'America/Sao_Paulo')::date as d)
select cli.reg, cli.nome, cli.tel_wa, cli.ativo,
       greatest(coalesce(t.saldo, 0), 0)  as saldo,
       greatest(-coalesce(t.saldo, 0), 0) as credito,
       an.venc as vencimento_mais_antigo,
       case when an.venc < hoje.d then hoje.d - an.venc else 0 end as dias_atraso
from cli
left join tot t on t.reg = cli.reg
left join antigo an on an.reg = cli.reg
cross join hoje
-- Cliente aparece se estiver ativo OU com saldo diferente de zero (devendo ou com credito).
-- Inativo e zerado some.
where cli.ativo or abs(coalesce(t.saldo, 0)) > 0.005;

revoke all on public.inove_clientes_v from public, anon;
grant select on public.inove_clientes_v to authenticated;

-- ── 7) Controle mensal sem comissao (colunas montadas a partir da tabela) ──
do $$
declare v_cols text;
begin
  select string_agg(format('m.%I', column_name), ', ' order by ordinal_position) into v_cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'controle_mensal'
     and column_name not in ('valor_pago_comissionado', 'extrato_url', 'extrato_path', 'user_id');
  execute 'drop view if exists public.inove_controle_mensal_v';
  execute format($v$
    create view public.inove_controle_mensal_v with (security_invoker = false) as
    select %s,
           case when public.ideali_e_dono() or public.inove_ve_extrato_pdf() then m.extrato_path end as extrato_path
    from public.controle_mensal m
    where (public.ideali_e_inove() or public.ideali_e_dono()) and m.user_id = public.ideali_dono_id()
  $v$, v_cols);
end $$;
revoke all on public.inove_controle_mensal_v from public, anon;
grant select on public.inove_controle_mensal_v to authenticated;

drop view if exists public.inove_config_v;
create view public.inove_config_v with (security_invoker = false) as
select coalesce(f.inove_whatsapp_frase, 'Olá, {nome}. Aqui é da Inove 3D, sobre seu pagamento/seus trabalhos.') as whatsapp_frase,
       coalesce(f.inove_ve_extrato_pdf, false) as ve_extrato_pdf
from (select public.ideali_dono_id() as id where public.ideali_e_inove() or public.ideali_e_dono()) dono
left join public.fin_config f on f.user_id = dono.id;
revoke all on public.inove_config_v from public, anon;
grant select on public.inove_config_v to authenticated;

-- ── 8) O que a Inove grava: recebido e conferido (travas da 049 continuam) ──
create or replace function public.inove_marcar_recebido(p_reg int, p_mes int, p_ano int, p_valor boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.ideali_e_inove() or public.ideali_e_dono()) then raise exception 'Sem permissao.'; end if;
  update controle_mensal set recebido = p_valor
   where cliente_reg = p_reg and mes = p_mes and ano = p_ano and user_id = public.ideali_dono_id();
  if not found then
    insert into controle_mensal (cliente_reg, mes, ano, recebido, user_id)
    values (p_reg, p_mes, p_ano, p_valor, public.ideali_dono_id());
  end if;
end;
$$;
revoke execute on function public.inove_marcar_recebido(int, int, int, boolean) from public, anon;
grant  execute on function public.inove_marcar_recebido(int, int, int, boolean) to authenticated;

create or replace function public.inove_marcar_conferido(p_reg int, p_mes int, p_ano int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.ideali_e_inove() or public.ideali_e_dono()) then raise exception 'Sem permissao.'; end if;
  update controle_mensal set confirmado_pela_inove = true
   where cliente_reg = p_reg and mes = p_mes and ano = p_ano and user_id = public.ideali_dono_id();
end;
$$;
revoke execute on function public.inove_marcar_conferido(int, int, int) from public, anon;
grant  execute on function public.inove_marcar_conferido(int, int, int) to authenticated;

-- Pedidos ainda nao entregues/cancelados criados no mes: SO a quantidade, sem valor
create or replace function public.inove_pedidos_pendentes(p_mes int, p_ano int)
returns table(cliente_reg int, qtd int, mais_antigo timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.ideali_e_inove() or public.ideali_e_dono()) then raise exception 'Sem permissao.'; end if;
  return query
    select p.cliente_reg::int, count(*)::int, min(p.created_at)
      from pedidos p
     where p.user_id = public.ideali_dono_id() and p.cliente_reg is not null
       and p.status not in ('entregue', 'cancelado')
       and (p.created_at at time zone 'America/Sao_Paulo') >= make_date(p_ano, p_mes + 1, 1)
       and (p.created_at at time zone 'America/Sao_Paulo') <  (make_date(p_ano, p_mes + 1, 1) + interval '1 month')
     group by p.cliente_reg;
end;
$$;
revoke execute on function public.inove_pedidos_pendentes(int, int) from public, anon;
grant  execute on function public.inove_pedidos_pendentes(int, int) to authenticated;

-- ── 9) Botao WhatsApp: cada clique fica no historico (quem, cliente, quando) ──
create table if not exists public.inove_whatsapp_cliques (
  id            bigint generated always as identity primary key,
  quando        timestamptz not null default now(),
  usuario_id    uuid,
  usuario_email text,
  papel         text,
  cliente_reg   int not null references public.cadastro_clientes(reg),
  user_id       uuid not null references auth.users(id)
);
create index if not exists inove_whatsapp_cliques_user_quando_idx on public.inove_whatsapp_cliques(user_id, quando desc);
alter table public.inove_whatsapp_cliques enable row level security;
revoke all on public.inove_whatsapp_cliques from anon, authenticated;
grant select on public.inove_whatsapp_cliques to authenticated;
drop policy if exists "dono le" on public.inove_whatsapp_cliques;
create policy "dono le" on public.inove_whatsapp_cliques for select to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid());

create or replace function public.inove_registrar_whatsapp(p_reg int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.ideali_e_inove() or public.ideali_e_dono()) then raise exception 'Sem permissao.'; end if;
  -- so cliente que aparece na lista (ativo ou com saldo) e com telefone valido
  if not exists (select 1 from inove_clientes_v v where v.reg = p_reg and v.tel_wa is not null) then
    raise exception 'Cliente sem telefone valido.';
  end if;
  insert into inove_whatsapp_cliques (usuario_id, usuario_email, papel, cliente_reg, user_id)
  values (auth.uid(), auth.jwt() ->> 'email', public.ideali_papel(), p_reg, public.ideali_dono_id());
end;
$$;
revoke execute on function public.inove_registrar_whatsapp(int) from public, anon;
grant  execute on function public.inove_registrar_whatsapp(int) to authenticated;

-- ── 10) inove_listar_clientes: endereco so para o dono ────────
create or replace function public.inove_listar_clientes()
returns table(reg integer, nome text, end_str text, bairro text, cidade text, uf text)
language plpgsql stable security definer set search_path = public as $$
declare v_dono boolean := public.ideali_e_dono();
begin
  if not (v_dono or public.ideali_e_inove()) then
    raise exception 'Sem permissao.';
  end if;
  return query
    select c.reg::integer, c.nome::text,
           case when v_dono then c.end_str::text end, case when v_dono then c.bairro::text end,
           case when v_dono then c.cidade::text end,  case when v_dono then c.uf::text end
    from cadastro_clientes c
    where c.user_id = public.ideali_dono_id()
      -- Inove: mesma regra da view (ativo OU saldo diferente de zero)
      and (v_dono or c.reg in (select v.reg from inove_clientes_v v));
end;
$$;
revoke execute on function public.inove_listar_clientes() from public, anon;
grant  execute on function public.inove_listar_clientes() to authenticated;

commit;

-- Conferencia rapida (rode depois, como dono, no SQL Editor nao funciona porque ali voce
-- e "postgres"; o teste de verdade e testes/teste_negacao_inove_052.py):
--   select tablename, policyname from public.ideali_politicas_guardadas where migracao = '052';
