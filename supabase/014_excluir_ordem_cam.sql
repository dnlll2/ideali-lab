-- ============================================================
-- Ideali Laboratorio - Excluir pedido do CAM (soft delete)
-- Botao "Excluir" em ordens-cam.html para cadastros de teste,
-- duplicados ou pedidos cancelados.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok).
--
-- Por que soft delete e nao DELETE de verdade: ordens_exocad
-- alimenta relatorio, comissao e outras telas -- um clique errado
-- (mesmo com confirmacao) seria irrecuperavel. "excluido" e um campo
-- separado de "arquivado" porque tem significado diferente: arquivado
-- e trabalho concluido que fica guardado pra historico (aparece em
-- "Ver arquivados"); excluido e lixo/teste/duplicado que nao deve
-- aparecer em lugar nenhum, nem la.
-- ============================================================

alter table ordens_exocad add column if not exists excluido boolean not null default false;
