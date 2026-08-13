-- ============================================================
-- Ideali Laboratorio - Portal do Cadista
-- atualizar_status_caso_cadista (005_portal_cadista_casos.sql) so
-- deixava avancar (a_fazer -> fazendo -> finalizado), nunca voltar.
-- No kanban (arrastar-e-soltar) isso aparecia como "nao consigo
-- arrastar de Fazendo pra A Fazer" -- o drop disparava a chamada, mas
-- o banco rejeitava com "Transicao de status invalida." e o card nao
-- mudava de coluna.
--
-- Agora aceita qualquer uma das 3 colunas, em qualquer direcao (o
-- cadista pode voltar um caso que marcou errado, por exemplo). Ao
-- sair de 'finalizado' pra qualquer outro status, finalizado_at volta
-- pra null (nao fica uma data de finalizacao "fantasma" num caso que
-- nao esta mais finalizado); ao (re)entrar em 'finalizado', grava
-- now() de novo, igual antes.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 005_portal_cadista_casos.sql
-- ja ter rodado antes.
-- ============================================================

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

  if p_novo_status not in ('a_fazer', 'fazendo', 'finalizado') then
    raise exception 'Status invalido.';
  end if;

  update ordens_exocad
    set status = p_novo_status,
        finalizado_at = case when p_novo_status = 'finalizado' then now() else null end
    where id = p_caso_id;
end;
$$;

grant execute on function atualizar_status_caso_cadista(text,uuid,text) to anon;
