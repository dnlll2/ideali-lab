-- ============================================================
-- Ideali Laboratorio - 047 Fecha funcoes internas
-- Gatilho e funcoes de apoio das regras nao precisam ser chamadas de fora.
-- (As funcoes dos portais continuam abertas de proposito: elas mesmas
-- conferem a sessao do portal.)
-- ============================================================
revoke execute on function public.log_controle_mensal_changes() from public, anon, authenticated;
revoke execute on function public.ideali_aal_ok(), public.ideali_dono_atual(), public.ideali_e_dono(),
  public.ideali_e_inove(), public.ideali_dono_id(), public.ideali_papel() from public, anon;
