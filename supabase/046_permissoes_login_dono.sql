-- ============================================================
-- Ideali Laboratorio - 046 Permissoes das telas de convite/cadastro
-- Antes essas tabelas so eram acessadas com a chave mestra. Agora o
-- dono logado precisa da permissao basica; quem decide o que cada um
-- ve continua sendo a regra "dono acessa tudo" (RLS) da 045.
-- portal_sessoes e ideali_config continuam fechadas (so funcoes do banco).
-- ============================================================
grant select, insert, update, delete on
  public.cadastro_cadistas, public.clientes_login, public.cadistas_login,
  public.convites, public.clientes_pendentes, public.cadistas_pendentes
to authenticated;
grant usage, select on all sequences in schema public to authenticated;
