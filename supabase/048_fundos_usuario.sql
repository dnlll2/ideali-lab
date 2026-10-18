-- 048 — "Usar minha foto" (Configurações › Aparência do Ideali Lab 2.0)
--
-- Bucket privado 'fundos': cada usuário logado só lê e grava dentro da
-- própria pasta, que tem o id dele (ex.: <auth.uid()>/fundo.jpg).
-- O app reduz a foto no aparelho para até ~300 KB antes de enviar; o limite
-- de 400 KB aqui é só uma trava a mais.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fundos', 'fundos', false, 409600, array['image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "fundo: le a propria pasta" on storage.objects;
create policy "fundo: le a propria pasta"
on storage.objects for select to authenticated
using (bucket_id = 'fundos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "fundo: envia na propria pasta" on storage.objects;
create policy "fundo: envia na propria pasta"
on storage.objects for insert to authenticated
with check (bucket_id = 'fundos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "fundo: troca na propria pasta" on storage.objects;
create policy "fundo: troca na propria pasta"
on storage.objects for update to authenticated
using (bucket_id = 'fundos' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'fundos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "fundo: apaga na propria pasta" on storage.objects;
create policy "fundo: apaga na propria pasta"
on storage.objects for delete to authenticated
using (bucket_id = 'fundos' and (storage.foldername(name))[1] = (select auth.uid())::text);
