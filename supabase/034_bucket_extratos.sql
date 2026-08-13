-- ============================================================
-- Ideali Laboratorio - Bucket de Storage para extratos (PDF)
--
-- contas-receber.html agora le automaticamente o "Extrato Individual"
-- (PDF) do Inove 3D ao anexar, extrai Total de Servicos / Saldo
-- Anterior / Pagamento Pix, mostra uma tela de conferencia contra o
-- que ja esta lancado, e so entao anexa o arquivo aqui.
--
-- Publico (mesmo padrao do bucket "comprovantes" ja existente) porque
-- o app usa a service_role key no client (risco ja aceito, ver
-- SUPABASE_KEY em shared.js) e le/mostra os PDFs via getPublicUrl.
--
-- Rode no SQL Editor do Supabase (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

insert into storage.buckets (id, name, public)
values ('extratos', 'extratos', true)
on conflict (id) do nothing;
