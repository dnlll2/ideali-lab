-- ============================================================
-- Ideali Laboratorio - Notificacao de caso finalizado pelo cadista
-- Adiciona o campo visto_pelo_admin em ordens_exocad: fica false
-- sempre que o CADISTA finaliza um caso pelo portal-cadista.html,
-- e volta pra true quando o admin confirma que viu (ordens-cam.html).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 005_portal_cadista_casos.sql
-- ja ter rodado antes (recria atualizar_status_caso_cadista de la).
--
-- Por que campo no banco em vez de so comparar finalizado_at com um
-- "ultimo visto" salvo no localStorage: assim o badge/destaque bate
-- igual em qualquer navegador/computador que abrir o ordens-cam.html,
-- e o "confirmar" fica registrado de verdade (nao depende do cache
-- do navegador que abriu a pagina).
-- ============================================================

alter table ordens_exocad add column if not exists visto_pelo_admin boolean not null default true;

-- ── Avancar status do caso (so a_fazer->fazendo e fazendo->finalizado) ──
-- Mesma funcao de 005, so acrescentando visto_pelo_admin = false quando
-- o novo status e 'finalizado' (o admin ainda nao viu esse finalizado).

create or replace function atualizar_status_caso_cadista(
  p_sessao      text,
  p_caso_id     uuid,
  p_novo_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao portal_sessoes%rowtype;
  v_ordem  ordens_exocad%rowtype;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cadista' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  select * into v_ordem from ordens_exocad
    where id = p_caso_id and cadista_reg = v_sessao.reg;
  if v_ordem.id is null then
    raise exception 'Caso nao encontrado ou nao atribuido a voce.';
  end if;

  if not (
    (v_ordem.status = 'a_fazer' and p_novo_status = 'fazendo') or
    (v_ordem.status = 'fazendo' and p_novo_status = 'finalizado')
  ) then
    raise exception 'Transicao de status invalida.';
  end if;

  update ordens_exocad
    set status = p_novo_status,
        finalizado_at = case when p_novo_status = 'finalizado' then now() else finalizado_at end,
        visto_pelo_admin = case when p_novo_status = 'finalizado' then false else visto_pelo_admin end
    where id = p_caso_id;
end;
$$;

grant execute on function atualizar_status_caso_cadista(text,uuid,text) to anon;
