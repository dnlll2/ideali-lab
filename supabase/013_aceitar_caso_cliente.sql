-- ============================================================
-- Ideali Laboratorio - Aceitar caso enviado pelo cliente
-- Distingue caso vindo do portal-cliente.html (precisa de aceite do
-- admin antes de entrar no fluxo normal) de caso cadastrado direto
-- pelo admin em ordens-cam.html (sempre aceito, sem trava nenhuma).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 003_portal_caso.sql ja
-- ter rodado antes (recria enviar_caso de la, so acrescentando
-- aceito_pelo_admin=false no insert).
--
-- Por que campo booleano em vez de um 4o valor de status: o campo
-- "status" (a_fazer/fazendo/finalizado) e enumerado em varios lugares
-- do ordens-cam.html (colunas do kanban, relatorio, badges, ordem de
-- avanco) que assumem so esses 3 valores. "Aceito pelo admin" nao e
-- um estagio do pipeline -- e um portao de entrada, resolvido uma
-- unica vez -- entao fica separado, no mesmo espirito do
-- visto_pelo_admin (011_visto_pelo_admin.sql).
-- ============================================================

alter table ordens_exocad add column if not exists aceito_pelo_admin boolean not null default true;

-- ── enviar_caso: mesma funcao de 003, so acrescentando
-- aceito_pelo_admin=false no insert (fica pendente ate o admin
-- aceitar em ordens-cam.html) ──

create or replace function enviar_caso(
  p_sessao       text,
  p_paciente     text,
  p_tipo_trabalho text,
  p_dentes       int[],
  p_cor          text,
  p_observacoes  text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao    portal_sessoes%rowtype;
  v_descricao text;
  v_id        uuid;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cliente' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  if p_paciente is null or trim(p_paciente) = '' then
    raise exception 'Informe o nome do paciente.';
  end if;
  if p_tipo_trabalho is null or trim(p_tipo_trabalho) = '' then
    raise exception 'Informe o tipo de trabalho.';
  end if;
  if p_dentes is null or array_length(p_dentes, 1) is null then
    raise exception 'Selecione ao menos um dente no odontograma.';
  end if;

  v_descricao := 'Paciente: ' || trim(p_paciente)
    || E'\n\nTipo de trabalho: ' || trim(p_tipo_trabalho)
    || E'\nDentes: ' || array_to_string(p_dentes, ', ')
    || E'\nCor: ' || coalesce(nullif(trim(p_cor), ''), '-')
    || case when coalesce(trim(p_observacoes), '') <> ''
         then E'\n\nObservacoes: ' || trim(p_observacoes)
         else '' end
    || E'\n\n[Anexo de arquivo (STL): upload em breve]';

  insert into ordens_exocad (cliente_reg, descricao, origem, status, aceito_pelo_admin)
  values (v_sessao.reg, v_descricao, 'portal', 'a_fazer', false)
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function enviar_caso(text,text,text,int[],text,text) to anon;
