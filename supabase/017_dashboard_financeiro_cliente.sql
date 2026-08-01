-- ============================================================
-- Ideali Laboratorio - Portal de Clientes
-- Etapa 7: Dashboard financeiro (aba "Financeiro" movida pro menu
-- hamburguer) -- alem do controle_mensal (valor fechado/pago/
-- restante, ja usado por listar_financeiro_cliente), agora tambem
-- mostra quantidade de pedidos e um grafico de "tipos de trabalho",
-- vindos da tabela pedidos.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 001_portal_convites.sql. Seguro rodar de novo (funcao usa
-- CREATE OR REPLACE).
--
-- Por que uma RPC nova em vez de reaproveitar alguma consulta direta:
-- pedidos e a tabela usada por pedidos.html (regra de negocio: so
-- ganha registro quando o caso ja foi confirmado como enviado ao
-- Inove -- ver pagamentos-inove.html/pedidos.html), bem diferente de
-- ordens_exocad (fila de producao interna). Nao existia nenhuma RPC
-- lendo pedidos filtrada por cliente ainda. Mesmo padrao de seguranca
-- das etapas anteriores: SECURITY DEFINER, valida a sessao
-- (portal_sessoes) antes de devolver qualquer linha, e o cliente_reg
-- do filtro vem da sessao validada, nunca de parametro que o cliente
-- poderia manipular -- um cliente nunca enxerga pedido de outro.
--
-- status='cancelado' fica de fora: um pedido cancelado nao deveria
-- contar pro cliente como "trabalho enviado" nem entrar no total
-- faturado/grafico. Os demais status (orcamento, producao,
-- finalizado, entregue) entram todos -- ver PED_STATUS em
-- pedidos.html.
-- ============================================================

create or replace function listar_pedidos_cliente(p_sessao text)
returns table(
  id            uuid,
  descricao     text,
  valor         numeric,
  status        text,
  material      text,
  qtd_elementos int,
  created_at    timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao portal_sessoes%rowtype;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cliente' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  return query
    select
      p.id,
      p.descricao,
      p.valor,
      p.status,
      p.material,
      p.qtd_elementos,
      p.created_at
    from pedidos p
    where p.cliente_reg = v_sessao.reg
      and p.status <> 'cancelado'
    order by p.created_at desc;
end;
$$;

grant execute on function listar_pedidos_cliente(text) to anon;
