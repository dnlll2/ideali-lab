-- ============================================================
-- Ideali Laboratorio - Upload de STL (JWT temporario por sessao)
-- Bucket privado no Storage + JWT curto (role anon, claim
-- cliente_reg) via pgjwt, pro cliente subir o arquivo direto no
-- Storage sem passar por Edge Function nenhuma.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de:
--  - 004_portal_meus_casos.sql (tabela portal_sessoes) ja aplicado.
--  - vault.create_secret('<Legacy JWT Secret do projeto>', 'jwt_hmac_secret', ...)
--    ja ter rodado ANTES, uma unica vez, fora deste arquivo (o segredo
--    NAO fica neste arquivo -- fica no Vault, nunca em texto puro no
--    git). Sem isso, gerar_jwt_upload falha com "Segredo JWT nao
--    configurado no Vault".
-- ============================================================

create extension if not exists pgjwt with schema extensions;

-- Bucket privado: sem leitura publica, tudo passa pelo JWT assinado.
insert into storage.buckets (id, name, public)
values ('casos', 'casos', false)
on conflict (id) do nothing;

-- ── Gerar JWT temporario de upload (10 min, role anon + claim cliente_reg) ──

create or replace function gerar_jwt_upload(p_sessao text)
returns text
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_sessao portal_sessoes%rowtype;
  v_secret text;
  v_token  text;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cliente' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'jwt_hmac_secret';
  if v_secret is null then
    raise exception 'Segredo JWT nao configurado no Vault.';
  end if;

  select extensions.sign(
    json_build_object(
      'role', 'anon',
      'cliente_reg', v_sessao.reg,
      'iss', 'supabase',
      'iat', extract(epoch from now())::int,
      'exp', extract(epoch from now() + interval '10 minutes')::int
    ),
    v_secret
  ) into v_token;

  return v_token;
end;
$$;

grant execute on function gerar_jwt_upload(text) to anon;

-- ── Politica de Storage: cliente so escreve dentro da propria pasta ──
-- Object path esperado dentro do bucket 'casos':
--   {cliente_reg}/{id_do_caso}/{nome_do_arquivo}
-- O claim cliente_reg do JWT tem que bater com o 1o segmento do path
-- -- e o unico jeito de escrever no bucket, ja que ele e privado e o
-- anon "de verdade" (sem esse JWT customizado) nao tem policy nenhuma
-- aqui.

drop policy if exists "cliente insere STL na propria pasta" on storage.objects;
create policy "cliente insere STL na propria pasta"
on storage.objects for insert
to anon
with check (
  bucket_id = 'casos'
  and (storage.foldername(name))[1] = (auth.jwt() ->> 'cliente_reg')
);
