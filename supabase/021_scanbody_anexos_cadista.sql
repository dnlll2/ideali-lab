-- ============================================================
-- Ideali Laboratorio - Anexos do pedido (Scanbody + reformulacao
-- do formulario em ordens-cam.html) + leitura desses anexos pelo
-- cadista no portal-cadista.html.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Depende de 016_upload_stl_jwt.sql
-- (bucket 'casos' + extensao pgjwt + secret no Vault) e
-- 005/020 (portal_sessoes tipo='cadista', cadista_reg) ja aplicados.
--
-- ordens-cam.html usa a service_role key (shared.js) -- bypassa RLS,
-- entao o admin ja consegue subir/listar/baixar arquivo em qualquer
-- pasta do bucket 'casos' sem policy nenhuma nova. So falta o
-- cadista conseguir LER (nunca escrever) os anexos dos casos
-- atribuidos a ele no portal, que roda com a anon key.
--
-- Mesmo esquema de 016 (upload do cliente): gera um JWT curto
-- (10 min, role anon, claim cliente_reg) que bate com a policy de
-- SELECT ja criada em 018 ("cliente le arquivos da propria pasta",
-- bucket_id='casos' e (storage.foldername(name))[1] = claim
-- cliente_reg) -- so que aqui quem pede o token e o cadista, e a
-- funcao confere que o caso pedido esta mesmo atribuido a ele
-- (cadista_reg = sessao) antes de emitir o token com o cliente_reg
-- DAQUELE caso.
-- ============================================================

create or replace function gerar_jwt_leitura_cadista(p_sessao text, p_caso_id uuid)
returns table(token text, pasta text)
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_sessao portal_sessoes%rowtype;
  v_ordem  ordens_exocad%rowtype;
  v_secret text;
  v_token  text;
begin
  select * into v_sessao from portal_sessoes
    where token = p_sessao and tipo = 'cadista' and expira_em > now();
  if v_sessao.token is null then
    raise exception 'Sessao expirada ou invalida. Faca login novamente.';
  end if;

  select * into v_ordem from ordens_exocad
    where id = p_caso_id and cadista_reg = v_sessao.reg;
  if v_ordem.id is null then
    raise exception 'Caso nao encontrado ou nao atribuido a voce.';
  end if;
  if v_ordem.cliente_reg is null then
    raise exception 'Este pedido nao tem cliente vinculado -- sem pasta de anexos.';
  end if;

  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'jwt_hmac_secret';
  if v_secret is null then
    raise exception 'Segredo JWT nao configurado no Vault.';
  end if;

  select extensions.sign(
    json_build_object(
      'role', 'anon',
      'cliente_reg', v_ordem.cliente_reg,
      'iss', 'supabase',
      'iat', extract(epoch from now())::int,
      'exp', extract(epoch from now() + interval '10 minutes')::int
    ),
    v_secret
  ) into v_token;

  return query select v_token, (v_ordem.cliente_reg::text || '/' || v_ordem.id::text);
end;
$$;

grant execute on function gerar_jwt_leitura_cadista(text, uuid) to anon;
