-- ============================================================
-- Ideali Laboratorio - Portal de Clientes
-- Etapa 2: Envio de Caso (paciente, tipo de trabalho, cor,
-- observacoes, odontograma) - upload de arquivo (STL) fica para
-- depois, quando a senha do banco estiver configurada.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 001_portal_convites.sql. Seguro rodar de novo (funcao usa
-- CREATE OR REPLACE).
--
-- Reaproveita a tabela ordens_exocad ja existente (mesma fila
-- Kanban usada internamente para WhatsApp/Email) em vez de criar
-- uma tabela paralela: o caso enviado pelo portal entra direto na
-- coluna "A Fazer" com origem='portal', igual um pedido recebido
-- por WhatsApp. cliente_reg vem da sessao validada (portal_sessoes),
-- nunca de um parametro que o cliente poderia manipular.
-- ============================================================

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

  insert into ordens_exocad (cliente_reg, descricao, origem, status)
  values (v_sessao.reg, v_descricao, 'portal', 'a_fazer')
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function enviar_caso(text,text,text,int[],text,text) to anon;
