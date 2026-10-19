-- ============================================================
-- Ideali Laboratorio - 049 Inove: ve tudo, edita so o que e dela
-- A Inove e a dona do negocio; a Ideali presta o servico (pedidos,
-- boleto, nota). Regras pedidas pelo dono em 18/10/2026:
--   VER: tudo (clientes completos, ordens CAM, tarefas, gastos...),
--        menos senhas/sessoes dos portais e o Estudio CAD (negocio separado).
--   EDITAR:
--   1) Controle mensal: so "recebido" e "conferido pela Inove".
--      Nunca valor do mes, valor pago ou qualquer outro campo.
--   2) Pagamentos: registra o pagamento dela com comprovante.
--      Depois de conferido (confirmado), nao altera nem apaga.
--   3) Vencimento do mes: so o dono.
--   4) Comprovantes: envia; substitui so antes da conferencia.
--   5) Comissao: so o dono registra e exclui.
--   + Historico de tudo que a Inove alterar (inove_alteracoes).
-- As travas ficam no banco (gatilhos), nao so na tela.
-- NAO altera nenhum dado ja gravado: so cria regras, gatilhos, a coluna vazia
-- criado_por e a tabela de historico. Para desfazer: 049_desfazer.sql.
-- Seguro rodar de novo.
-- ============================================================

-- ── Apoio: true quando todos os valores do json estao "vazios" (nulo, 0, false, '') ──
create or replace function public.ideali_so_vazios(j jsonb)
returns boolean language sql immutable set search_path = '' as $$
  select coalesce(bool_and(
           e.value in ('null'::jsonb, 'false'::jsonb, '""'::jsonb)
           or (jsonb_typeof(e.value) = 'number' and e.value::text::numeric = 0)), true)
  from jsonb_each(j) e
$$;
revoke execute on function public.ideali_so_vazios(jsonb) from public, anon;
grant  execute on function public.ideali_so_vazios(jsonb) to authenticated;

-- ── VER: leitura para a Inove nas tabelas que ela ainda nao lia ──
do $$
declare t text;
begin
  foreach t in array array['cadastro_clientes', 'cadastro_cadistas', 'ordens_exocad', 'tarefas',
                           'gastos_entrega', 'tabela_precos', 'config_mes', 'controle_mensal_historico',
                           'inove_clientes', 'inove_pedidos', 'inove_controle_mensal']
  loop
    execute format('drop policy if exists "inove select" on public.%I', t);
    execute format('create policy "inove select" on public.%I for select to authenticated
                    using (public.ideali_e_inove() and user_id = public.ideali_dono_id())', t);
  end loop;
end $$;

-- Arquivos dos casos (STL das ordens CAM): Inove pode abrir/baixar
drop policy if exists "inove le comprovantes e extratos" on storage.objects;
create policy "inove le comprovantes e extratos" on storage.objects for select to authenticated
  using (bucket_id in ('comprovantes', 'extratos', 'casos') and public.ideali_e_inove());

-- ── 3) Vencimento do mes: so o dono ──
drop policy if exists "inove insert" on public.vencimento_mensal;
drop policy if exists "inove update" on public.vencimento_mensal;
drop policy if exists "inove delete" on public.vencimento_mensal;

-- ── Historico do que a Inove alterar ──
create table if not exists public.inove_alteracoes (
  id            bigserial primary key,
  quando        timestamptz not null default now(),
  usuario_id    uuid,
  usuario_email text,
  tabela        text not null,
  registro_id   text,
  acao          text not null,
  antes         jsonb,
  depois        jsonb,
  user_id       uuid references auth.users(id) default public.ideali_dono_atual()
);
create index if not exists inove_alteracoes_user_quando_idx on public.inove_alteracoes(user_id, quando desc);
alter table public.inove_alteracoes enable row level security;
revoke all on public.inove_alteracoes from anon, authenticated;
grant select on public.inove_alteracoes to authenticated;
drop policy if exists "dono le" on public.inove_alteracoes;
create policy "dono le" on public.inove_alteracoes for select to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid());
drop policy if exists "inove le" on public.inove_alteracoes;
create policy "inove le" on public.inove_alteracoes for select to authenticated
  using (public.ideali_e_inove() and user_id = public.ideali_dono_id());

create or replace function public.inove_registrar_alteracao()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_antes  jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  v_depois jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
begin
  if not public.ideali_e_inove() then return null; end if;
  if tg_op = 'UPDATE' and v_antes = v_depois then return null; end if;
  insert into inove_alteracoes (usuario_id, usuario_email, tabela, registro_id, acao, antes, depois, user_id)
  values (auth.uid(), auth.jwt() ->> 'email', tg_table_name,
          coalesce(v_depois ->> 'id', v_antes ->> 'id'),
          lower(tg_op) || case when current_setting('ideali.sistema', true) = 'on' then ' (automatico)' else '' end,
          v_antes, v_depois, public.ideali_dono_id());
  return null;
end;
$$;
revoke execute on function public.inove_registrar_alteracao() from public, anon, authenticated;

-- ── 1) Controle mensal: Inove so mexe em "recebido" e "conferido pela Inove" ──
create or replace function public.inove_trava_controle_mensal()
returns trigger language plpgsql set search_path = public as $$
declare
  livres text[] := array['recebido', 'confirmado_pela_inove', 'updated_at'];
begin
  if not public.ideali_e_inove() or current_setting('ideali.sistema', true) = 'on' then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' then
    raise exception 'A Inove nao pode apagar lancamentos do controle mensal.';
  end if;
  if tg_op = 'INSERT' then
    if not public.ideali_so_vazios(to_jsonb(new) - (livres || array['id', 'cliente_reg', 'mes', 'ano', 'created_at', 'user_id'])) then
      raise exception 'A Inove so pode marcar recebido/conferido; valores sao lancados pela Ideali.';
    end if;
    if new.confirmado_pela_inove is false then
      raise exception 'A Inove so pode marcar como conferido.';
    end if;
    return new;
  end if;
  if (to_jsonb(new) - livres) <> (to_jsonb(old) - livres) then
    raise exception 'A Inove so pode alterar recebido e conferido; valores sao lancados pela Ideali.';
  end if;
  if old.confirmado_pela_inove is not false and new.confirmado_pela_inove is false then
    raise exception 'A Inove so pode marcar como conferido.';
  end if;
  return new;
end;
$$;
revoke execute on function public.inove_trava_controle_mensal() from public, anon, authenticated;

drop trigger if exists inove_trava on public.controle_mensal;
create trigger inove_trava before insert or update or delete on public.controle_mensal
  for each row execute function public.inove_trava_controle_mensal();
drop trigger if exists inove_historico on public.controle_mensal;
create trigger inove_historico after insert or update or delete on public.controle_mensal
  for each row execute function public.inove_registrar_alteracao();

-- ── 2) Pagamentos: Inove registra o dela; depois de conferido, nao muda ──
-- coluna nova, vazia nos pagamentos que ja existem (nenhum valor gravado muda)
alter table public.pagamento_aportes add column if not exists criado_por uuid;
alter table public.pagamento_aportes alter column criado_por set default auth.uid();

create or replace function public.inove_trava_pagamento()
returns trigger language plpgsql set search_path = public as $$
declare
  livres_ins text[] := array['id', 'cliente_reg', 'mes', 'ano', 'valor', 'data_pagamento', 'comprovante_path',
                             'comprovante_url', 'obs', 'created_at', 'user_id', 'criado_por'];
  leitura    text[] := array['conferencia_valor', 'conferencia_status', 'conferencia_obs',
                             'conferencia_data_texto', 'conferido_em'];
  arquivo    text[] := array['comprovante_path', 'comprovante_url'];
  marcas     text[] := array['visto_inove_em', 'confirmado_inove_em'];
  dela       boolean;
begin
  if not public.ideali_e_inove() then return coalesce(new, old); end if;
  if tg_op = 'DELETE' then
    raise exception 'A Inove nao pode apagar pagamentos.';
  end if;
  if tg_op = 'INSERT' then
    new.criado_por := auth.uid();
    if coalesce(new.valor, 0) <= 0 then raise exception 'Valor do pagamento precisa ser maior que zero.'; end if;
    if not public.ideali_so_vazios(to_jsonb(new) - livres_ins) then
      raise exception 'Pagamento novo da Inove so pode ter cliente, mes, valor, data, comprovante e observacao.';
    end if;
    return new;
  end if;
  -- UPDATE
  if old.confirmado_inove_em is not null and (to_jsonb(new) - 'visto_inove_em') <> (to_jsonb(old) - 'visto_inove_em') then
    raise exception 'Pagamento ja conferido: nao pode mais ser alterado.';
  end if;
  if (to_jsonb(new) - (leitura || arquivo || marcas)) <> (to_jsonb(old) - (leitura || arquivo || marcas)) then
    raise exception 'A Inove nao pode alterar valor, data, cliente ou mes de um pagamento.';
  end if;
  if (old.visto_inove_em is not null and new.visto_inove_em is distinct from old.visto_inove_em)
     or (old.confirmado_inove_em is not null and new.confirmado_inove_em is distinct from old.confirmado_inove_em) then
    raise exception 'Marcacao de visto/conferido nao pode ser desfeita.';
  end if;
  dela := old.criado_por = auth.uid();
  if new.comprovante_path is distinct from old.comprovante_path
     or new.comprovante_url is distinct from old.comprovante_url then
    if not dela then raise exception 'A Inove so substitui comprovante de pagamento que ela registrou.'; end if;
  end if;
  if (to_jsonb(new) - (arquivo || marcas)) <> (to_jsonb(old) - (arquivo || marcas)) then
    -- leitura automatica do comprovante: so uma vez, logo depois de registrar o pagamento dela
    if not dela or old.conferido_em is not null then
      raise exception 'A leitura automatica do comprovante ja foi feita.';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.inove_trava_pagamento() from public, anon, authenticated;

drop trigger if exists inove_trava on public.pagamento_aportes;
create trigger inove_trava before insert or update or delete on public.pagamento_aportes
  for each row execute function public.inove_trava_pagamento();
drop trigger if exists inove_historico on public.pagamento_aportes;
create trigger inove_historico after insert or update or delete on public.pagamento_aportes
  for each row execute function public.inove_registrar_alteracao();

-- Pagamento novo da Inove: o banco SOMA o valor dele ao "valor pago" do mes -- assim a
-- Inove nunca grava o valor pago diretamente. So acrescenta o pagamento novo: meses antigos
-- e valores digitados a mao nunca sao recalculados (16 meses tem valor pago diferente da
-- soma dos pagamentos -- valores avulsos de mai-jun/2026 e um "legado" de jul/2026).
create or replace function public.inove_pagamento_soma_mes()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.ideali_e_inove() then return null; end if;
  perform set_config('ideali.sistema', 'on', true);
  update controle_mensal set valor_pago = coalesce(valor_pago, 0) + new.valor, confirmado_pela_inove = false, updated_at = now()
    where cliente_reg = new.cliente_reg and mes = new.mes and ano = new.ano and user_id = new.user_id;
  if not found then
    insert into controle_mensal (cliente_reg, mes, ano, valor_pago, confirmado_pela_inove, user_id)
      values (new.cliente_reg, new.mes, new.ano, new.valor, false, new.user_id);
  end if;
  perform set_config('ideali.sistema', 'off', true);
  return null;
end;
$$;
revoke execute on function public.inove_pagamento_soma_mes() from public, anon, authenticated;

drop trigger if exists inove_soma_mes on public.pagamento_aportes;
create trigger inove_soma_mes after insert on public.pagamento_aportes
  for each row execute function public.inove_pagamento_soma_mes();

-- ── 5) Comissao: so o dono (vale tambem dentro de pagar_comissao/excluir_comissao_paga) ──
create or replace function public.inove_trava_comissao()
returns trigger language plpgsql set search_path = public as $$
begin
  if public.ideali_e_inove() then
    raise exception 'Comissao e registrada e excluida so pela Ideali.';
  end if;
  return coalesce(new, old);
end;
$$;
revoke execute on function public.inove_trava_comissao() from public, anon, authenticated;
drop trigger if exists inove_trava on public.comissoes_pagas;
create trigger inove_trava before insert or update or delete on public.comissoes_pagas
  for each row execute function public.inove_trava_comissao();

-- ── 4) Comprovantes: envia; substitui so o dela e so antes da conferencia ──
drop policy if exists "inove envia comprovante" on storage.objects;
create policy "inove envia comprovante" on storage.objects for insert to authenticated
  with check (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'aportes' and public.ideali_e_inove());

drop policy if exists "inove substitui comprovante" on storage.objects;
create policy "inove substitui comprovante" on storage.objects for update to authenticated
  using (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'aportes' and public.ideali_e_inove()
         and owner_id = auth.uid()::text
         and not exists (select 1 from public.pagamento_aportes a
                         where a.comprovante_path = objects.name and a.confirmado_inove_em is not null))
  with check (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'aportes' and public.ideali_e_inove()
              and owner_id = auth.uid()::text);
