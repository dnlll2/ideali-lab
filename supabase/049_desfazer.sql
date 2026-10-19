-- ============================================================
-- Ideali Laboratorio - DESFAZ a 049 (volta as regras da Inove como estavam na 045)
-- Nao apaga nenhum pedido, pagamento ou lancamento.
-- O historico inove_alteracoes NAO e apagado aqui (fica guardado, so para de
-- receber registros). Para apagar tambem, rode a ultima linha comentada.
-- ============================================================

-- Gatilhos e funcoes da 049
drop trigger if exists inove_trava     on public.controle_mensal;
drop trigger if exists inove_historico on public.controle_mensal;
drop trigger if exists inove_trava     on public.pagamento_aportes;
drop trigger if exists inove_historico on public.pagamento_aportes;
drop trigger if exists inove_soma_mes  on public.pagamento_aportes;
drop trigger if exists inove_trava     on public.comissoes_pagas;
drop function if exists public.inove_trava_controle_mensal();
drop function if exists public.inove_trava_pagamento();
drop function if exists public.inove_pagamento_soma_mes();
drop function if exists public.inove_trava_comissao();
drop function if exists public.inove_registrar_alteracao();
drop function if exists public.ideali_so_vazios(jsonb);

-- Leitura extra que a 049 deu para a Inove
do $$
declare t text;
begin
  foreach t in array array['cadastro_clientes', 'cadastro_cadistas', 'ordens_exocad', 'tarefas',
                           'gastos_entrega', 'tabela_precos', 'config_mes', 'controle_mensal_historico',
                           'inove_clientes', 'inove_pedidos', 'inove_controle_mensal']
  loop
    execute format('drop policy if exists "inove select" on public.%I', t);
  end loop;
end $$;

-- Regras de arquivos como na 045
drop policy if exists "inove le comprovantes e extratos" on storage.objects;
create policy "inove le comprovantes e extratos" on storage.objects for select to authenticated
  using (bucket_id in ('comprovantes', 'extratos') and public.ideali_e_inove());
drop policy if exists "inove substitui comprovante" on storage.objects;
create policy "inove substitui comprovante" on storage.objects for update to authenticated
  using (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'aportes' and public.ideali_e_inove())
  with check (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'aportes' and public.ideali_e_inove());

-- Vencimento do mes: Inove volta a editar, como na 045
drop policy if exists "inove insert" on public.vencimento_mensal;
create policy "inove insert" on public.vencimento_mensal for insert to authenticated with check (public.ideali_e_inove() and user_id = public.ideali_dono_id());
drop policy if exists "inove update" on public.vencimento_mensal;
create policy "inove update" on public.vencimento_mensal for update to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id()) with check (public.ideali_e_inove() and user_id = public.ideali_dono_id());
drop policy if exists "inove delete" on public.vencimento_mensal;
create policy "inove delete" on public.vencimento_mensal for delete to authenticated using (public.ideali_e_inove() and user_id = public.ideali_dono_id());

-- Coluna "quem registrou" do pagamento (so foi criada pela 049)
alter table public.pagamento_aportes drop column if exists criado_por;

-- drop table if exists public.inove_alteracoes;
