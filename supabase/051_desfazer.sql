-- ============================================================
-- Ideali Laboratorio - DESFAZ a 051 (Central do Financeiro, Modulo 1)
--
-- Remove funcoes, gatilhos e tabelas criadas pela 051 e tira o limite
-- de tipo/tamanho do bucket "extratos".
--
-- ATENCAO:
--  * Apaga o HISTORICO gravado nessas tabelas (extratos_arquivos, fin_envios,
--    fin_auditoria, apelidos, uso da IA, chave Pix, modelos). Se quiser guardar,
--    exporte antes (Table Editor > Export to CSV).
--  * NAO mexe no controle_mensal: os extratos anexados pela Central continuam
--    ligados ao mes (extrato_url / extrato_path), como se tivessem sido anexados
--    pela tela A receber.
--  * O bucket "extratos" CONTINUA PRIVADO: torna-lo publico de novo reabriria o
--    vazamento de 2026-10 (ver 045). Isto e intencional.
--  * saldo_abertura_clientes e apagada junto (foi recriada pela 051).
-- ============================================================

do $$
declare t text;
begin
  foreach t in array array['controle_mensal', 'pagamento_aportes', 'saldo_abertura_clientes', 'fin_config',
                           'extratos_arquivos', 'fin_envios', 'apelidos_pagador', 'fin_lotes']
  loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists fin_auditoria on public.%I', t);
    end if;
  end loop;
end $$;

drop function if exists public.fin_ia_consumir(text, text, numeric);
drop function if exists public.fin_desfazer_ultimo_lote();
drop function if exists public.fin_anexar_extrato(jsonb);
drop function if exists public.fin_auditar();

drop table if exists public.fin_envios;
drop table if exists public.extratos_arquivos;
drop table if exists public.fin_lotes;
drop table if exists public.fin_ia_uso;
drop table if exists public.apelidos_pagador;
drop table if exists public.fin_auditoria;
drop table if exists public.fin_config;
drop table if exists public.saldo_abertura_clientes;

update storage.buckets set file_size_limit = null, allowed_mime_types = null where id = 'extratos';
