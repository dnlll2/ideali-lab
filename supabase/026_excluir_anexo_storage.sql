-- ============================================================
-- Ideali Laboratorio - Excluir anexo do bucket 'casos'
--
-- Ate aqui so existiam policies de INSERT (016_upload_stl_jwt.sql) e
-- SELECT (018_editar_caso_cliente.sql) pro JWT temporario (role anon +
-- claim cliente_reg). Sem policy de DELETE, nem o proprio cliente nem
-- o cadista (que usa o mesmo esquema de JWT via gerar_jwt_leitura_cadista,
-- 021_scanbody_anexos_cadista.sql) conseguiam excluir um anexo ja
-- enviado -- so o admin (ordens-cam.html, service_role, bypassa RLS).
--
-- Mesma trava de sempre: só apaga dentro da propria pasta
-- (1o segmento do path bate com o claim cliente_reg do JWT).
-- Repara que essa policy nao sabe distinguir "slot" (STL vs
-- Escaneamento etc.) -- quem decide quais anexos cada um pode excluir
-- na pratica e a UI (o cadista so tem botao de excluir nos campos que
-- ele mesmo pode subir: HTML/STL/Foto do Scanbody/Detalhado).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 016_upload_stl_jwt.sql
-- ja ter rodado antes.
-- ============================================================

drop policy if exists "cliente exclui arquivo da propria pasta" on storage.objects;
create policy "cliente exclui arquivo da propria pasta"
on storage.objects for delete
to anon
using (
  bucket_id = 'casos'
  and (storage.foldername(name))[1] = (auth.jwt() ->> 'cliente_reg')
);
