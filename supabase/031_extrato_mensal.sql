-- ============================================================
-- Ideali Laboratorio - Extrato mensal da Inove (anexo por cliente/mes)
-- Novo campo em controle_mensal pra guardar o PDF do extrato do mes
-- que a Inove manda -- diferente dos comprovantes de pagamento
-- individuais (que ficam no bucket "comprovantes" e podem ser varios
-- por mes). O extrato e 1 por cliente/mes, por isso vira coluna na
-- propria linha de controle_mensal em vez de tabela/bucket com lista.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Seguro rodar de novo (ADD COLUMN
-- IF NOT EXISTS / bucket com ON CONFLICT DO NOTHING).
--
-- Visivel em contas-receber.html (upload, pela Ideali) e em
-- pagamentos-inove.html (link "Ver extrato", so leitura, pela
-- Elisangela).
-- ============================================================

alter table controle_mensal
  add column if not exists extrato_url  text,
  add column if not exists extrato_path text;

-- Bucket publico (mesmo padrao do bucket "comprovantes" ja em uso):
-- link direto via getPublicUrl, sem passar por JWT/Edge Function.
insert into storage.buckets (id, name, public)
values ('extratos', 'extratos', true)
on conflict (id) do nothing;

drop policy if exists "extratos - leitura publica" on storage.objects;
create policy "extratos - leitura publica"
on storage.objects for select
to public
using (bucket_id = 'extratos');

drop policy if exists "extratos - anon gerencia" on storage.objects;
create policy "extratos - anon gerencia"
on storage.objects for all
to anon
using (bucket_id = 'extratos')
with check (bucket_id = 'extratos');
