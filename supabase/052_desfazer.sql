-- ============================================================
-- Ideali Laboratorio - DESFAZ a 052 (Inove: so acompanhamento)
--
-- Volta a Inove a ver o que via depois da 049: recria, exatamente como estavam,
-- as politicas guardadas em ideali_politicas_guardadas (migracao '052'), devolve
-- a leitura de extratos/comprovantes no Storage e o endereco em inove_listar_clientes.
--
-- ATENCAO:
--  * Apaga o historico de cliques no WhatsApp (inove_whatsapp_cliques).
--    Se quiser guardar: Table Editor > inove_whatsapp_cliques > Export to CSV.
--  * Os telefones digitados continuam em cadastro_clientes.tel (so some a coluna
--    calculada tel_wa). O historico de trocas de telefone fica em fin_auditoria.
--  * A tela nova (pagamentos-inove.html) depende da 052: volte o arquivo junto
--    (git) ou a Inove vera erro ao carregar a lista de clientes.
-- Seguro rodar de novo.
-- ============================================================

begin;

-- 1) Recria as politicas guardadas
do $$
declare r record; v_roles text;
begin
  if to_regclass('public.ideali_politicas_guardadas') is null then return; end if;
  for r in select * from public.ideali_politicas_guardadas where migracao = '052' loop
    select string_agg(case when x = 'public' then 'public' else quote_ident(x) end, ', ') into v_roles from unnest(r.roles) x;
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
    execute format('create policy %I on %I.%I as %s for %s to %s%s%s',
                   r.policyname, r.schemaname, r.tablename, r.permissive, r.cmd, v_roles,
                   case when r.qual is not null then ' using (' || r.qual || ')' else '' end,
                   case when r.with_check is not null then ' with check (' || r.with_check || ')' else '' end);
  end loop;
  delete from public.ideali_politicas_guardadas where migracao = '052';
end $$;

-- 2) Storage: tira as duas politicas novas (a antiga voltou no passo 1)
drop policy if exists "inove le comprovantes" on storage.objects;
drop policy if exists "inove le extratos se liberado" on storage.objects;

-- 3) Views e funcoes novas
drop view if exists public.inove_clientes_v;
drop view if exists public.inove_controle_mensal_v;
drop view if exists public.inove_config_v;
drop function if exists public.inove_marcar_recebido(int, int, int, boolean);
drop function if exists public.inove_marcar_conferido(int, int, int);
drop function if exists public.inove_pedidos_pendentes(int, int);
drop function if exists public.inove_registrar_whatsapp(int);
drop function if exists public.ideali_desfazer_tel(int);
drop function if exists public.inove_ve_extrato_pdf();
drop function if exists public.fin_vencimento(int, int);
drop function if exists public.fin_pascoa(int);
drop table if exists public.inove_whatsapp_cliques;

-- 4) Telefone calculado e historico de troca
drop trigger if exists ideali_auditar_tel on public.cadastro_clientes;
drop function if exists public.ideali_auditar_tel();
alter table public.cadastro_clientes drop column if exists tel_wa;
drop function if exists public.ideali_tel_wa(text);

-- 5) Ajustes em fin_config
alter table public.fin_config drop column if exists inove_whatsapp_frase;
alter table public.fin_config drop column if exists inove_ve_extrato_pdf;

-- 6) inove_listar_clientes como era na 045 (com endereco, todos os clientes)
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

commit;
