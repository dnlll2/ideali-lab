-- ============================================================
-- Ideali Laboratorio - Portal do Cadista
-- Etapa 8: Kanban com drag-and-drop (3 colunas: A Fazer / Fazendo /
-- Finalizado) substituindo os botoes "Iniciar"/"Finalizar", com um
-- aviso "Desfazer" pos-arraste.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 005_portal_cadista_casos.sql. Seguro rodar de novo (CREATE OR
-- REPLACE, mesma assinatura/tipo de retorno de antes -- nao precisa
-- de DROP).
--
-- Por que mudar atualizar_status_caso_cadista: antes so permitia
-- avancar (a_fazer->fazendo, fazendo->finalizado), o que bastava
-- pros botoes de clique. O "Desfazer" (voltar um passo depois de um
-- arraste) e o proprio drag-and-drop (que deixa soltar em qualquer
-- coluna, inclusive pra tras) agora precisam de transicao nos dois
-- sentidos. Continua so permitindo passos adjacentes -- nunca pular
-- direto de A Fazer pra Finalizado (nem na volta).
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

  if not (
    (v_ordem.status = 'a_fazer'    and p_novo_status = 'fazendo') or
    (v_ordem.status = 'fazendo'    and p_novo_status = 'a_fazer') or
    (v_ordem.status = 'fazendo'    and p_novo_status = 'finalizado') or
    (v_ordem.status = 'finalizado' and p_novo_status = 'fazendo')
  ) then
    raise exception 'Transicao de status invalida.';
  end if;

  update ordens_exocad
    set status = p_novo_status,
        finalizado_at = case when p_novo_status = 'finalizado' then now() else finalizado_at end
    where id = p_caso_id;
end;
$$;

grant execute on function atualizar_status_caso_cadista(text,uuid,text) to anon;
