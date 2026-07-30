-- ============================================================
-- Ideali Laboratorio - Portal de Clientes
-- Etapa 5: Aba "Financeiro" (painel desktop) - mostra pro cliente,
-- mes a mes, o valor fechado (valor_mes), quanto ja pagou
-- (valor_pago) e o restante (valor_mes - valor_pago).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok), depois de ja ter rodado
-- 001_portal_convites.sql. Seguro rodar de novo (funcao usa
-- CREATE OR REPLACE).
--
-- Mesmo padrao de seguranca das etapas anteriores: SECURITY
-- DEFINER, valida a sessao (portal_sessoes) antes de devolver
-- qualquer linha, e o cliente_reg usado no filtro vem da sessao
-- validada, nunca de um parametro que o cliente poderia
-- manipular -- um cliente nunca enxerga o financeiro de outro.
-- ============================================================

create or replace function listar_financeiro_cliente(p_sessao text)
returns table(
  mes        int,
  ano        int,
  valor_mes  numeric,
  valor_pago numeric,
  restante   numeric,
  quitado    boolean
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
      cm.mes,
      cm.ano,
      cm.valor_mes,
      cm.valor_pago,
      (cm.valor_mes - cm.valor_pago) as restante,
      cm.quitado
    from controle_mensal cm
    where cm.cliente_reg = v_sessao.reg
    order by cm.ano desc, cm.mes desc
    limit 12;
end;
$$;

grant execute on function listar_financeiro_cliente(text) to anon;
