-- ============================================================
-- Ideali Laboratorio - Ordens CAM
-- Guarda quais dentes exatos foram marcados no odontograma do
-- ordens-cam.html (Nova/Editar Ordem), nao so a contagem
-- (qtd_elementos). Sem essa coluna, toda vez que o admin reabria uma
-- ordem pra editar outra coisa (ex: anexar um arquivo), o
-- odontograma vinha zerado -- so mostrava "Atual: N elemento(s)" em
-- texto -- e se ele clicasse de novo nos mesmos dentes pra "lembrar
-- a selecao", nada persistia visualmente na proxima vez que abrisse.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

alter table ordens_exocad add column if not exists dentes int[];
