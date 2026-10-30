-- ============================================================
-- Ideali Laboratorio - Estudio CAD: pagamentos
-- Cada pagamento recebido de um cliente do Estudio (valor, data,
-- forma, comprovante) e os pedidos finalizados que ele quita.
-- Ao salvar, o estudio-cad.html marca esses pedidos como pagos
-- (pago=true, pago_em=data_pagamento); ao excluir, desmarca.
-- Comprovante vai pro bucket 'casos' em
-- estudio/pagamentos/<pagamento_id>/comprovante-<arquivo>.
-- Mesmo principio da 039: nada aqui entra no financeiro Inove.
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase
-- (projeto alqhhgysvehtgkwsxeok). Seguro rodar de novo.
-- ============================================================

create table if not exists estudio_pagamentos (
  id               uuid primary key default gen_random_uuid(),
  cliente_id       uuid not null references estudio_clientes(id),
  valor            numeric(10,2) not null default 0,
  data_pagamento   date not null default current_date,
  forma            text,          -- Pix, Dinheiro, Transferencia, Cartao, Outro
  pedido_ids       uuid[] not null default '{}',
  observacao       text,
  created_at       timestamptz not null default now()
);

create index if not exists estudio_pagamentos_cliente_idx on estudio_pagamentos(cliente_id);

alter table estudio_pagamentos enable row level security;
