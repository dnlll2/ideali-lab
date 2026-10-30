-- ============================================================
-- Ideali Laboratorio - Estudio CAD: quem desenha o pedido
-- Texto livre (ex.: 'Eu', 'Daniel Hosda'); a lista de opcoes fica
-- em EC_CADISTAS no estudio-cad.html. Nao referencia cadastro_cadistas,
-- mesmo principio da 039: o Estudio CAD e separado do fluxo Inove.
-- O comprovante de pagamento nao precisa de coluna: vai pro bucket
-- 'casos' em estudio/<pedido_id>/comprovante-<arquivo>.
-- ============================================================

alter table estudio_pedidos add column if not exists cadista text;
