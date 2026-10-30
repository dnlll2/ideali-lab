-- ============================================================
-- Ideali Laboratorio - 051 Central do Financeiro, Modulo 1 (extratos em lote)
--
-- So ACRESCENTA tabelas, funcoes e gatilhos. Nao altera nem apaga nenhum
-- dado existente, e nao cria coluna nova em controle_mensal (a Inove le
-- controle_mensal inteiro; tudo que e so deste modulo fica em tabela propria).
--
--   saldo_abertura_clientes  saldo inicial de cada cliente antes do sistema (14/06/2026).
--                            A 036 criou e a reversao de 20/08 apagou; volta VAZIA.
--                            O "Saldo Anterior" do extrato so serve para conferir contra ela.
--   fin_config               chave Pix, modelos de mensagem, limite diario da IA, e-mail
--   fin_lotes                cada importacao (para "Desfazer ultima importacao")
--   extratos_arquivos        historico de todo extrato anexado (hash, total lido, divergencia)
--   fin_envios               historico de envios por WhatsApp (extrato/recibo/cobranca)
--   fin_ia_uso               cada leitura feita pela IA (modelo, tokens, custo) - limite diario
--   apelidos_pagador         nome lido (extrato/comprovante) -> cliente; aprende com correcoes
--   fin_auditoria            quem, quando, o que mudou (antes/depois) em tudo do financeiro
--
-- A Inove NAO tem politica de leitura em nenhuma tabela nova (so o dono acessa).
-- Bucket "extratos": continua privado; passa a aceitar so PDF de ate 5 MB.
--
-- Meses: mes e 0-indexado (0 = janeiro ... 11 = dezembro), igual ao resto do sistema.
-- Desfazer: supabase/051_desfazer.sql
-- Rode este arquivo inteiro, uma vez, no SQL Editor (projeto alqhhgysvehtgkwsxeok).
-- ============================================================

-- ── Saldo de abertura ─────────────────────────────────────────
create table if not exists public.saldo_abertura_clientes (
  id              uuid primary key default gen_random_uuid(),
  cliente_reg     int not null references public.cadastro_clientes(reg),
  valor           numeric not null,              -- > 0: cliente devia ao laboratorio; < 0: credito do cliente
  data_referencia date not null default date '2026-06-14',
  fonte           text,
  observacao      text,
  verificado      boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  user_id         uuid not null references auth.users(id) default public.ideali_dono_atual(),
  unique (user_id, cliente_reg)
);

-- ── Configuracao do financeiro (uma linha por dono) ───────────
create table if not exists public.fin_config (
  user_id              uuid primary key references auth.users(id) default public.ideali_dono_atual(),
  chave_pix            text,
  modelo_extrato       text not null default 'Olá, {nome}. Segue o extrato de {mes} do Ideali Laboratório: total R$ {valor}, pago R$ {pago}, saldo R$ {saldo}. Vencimento em {vencimento}. Qualquer divergência, nos avise. Obrigado.',
  ia_modelo            text not null default 'claude-opus-5-5',
  ia_limite_diario_usd numeric not null default 0 check (ia_limite_diario_usd >= 0),  -- 0 = IA desligada (padrao)
  ia_max_leituras_dia  int not null default 200 check (ia_max_leituras_dia >= 0),  -- trava contra repeticao/abuso
  email_resumo         text not null default 'contato.idealilab@gmail.com',
  data_inicio_sistema  date not null default date '2026-06-14',
  updated_at           timestamptz not null default now()
);

-- ── Lotes de importacao ───────────────────────────────────────
create table if not exists public.fin_lotes (
  id           uuid primary key default gen_random_uuid(),
  tipo         text not null check (tipo in ('extratos', 'comprovantes')),
  criado_em    timestamptz not null default now(),
  criado_por   uuid default auth.uid(),
  resumo       jsonb,
  desfeito_em  timestamptz,
  desfeito_por uuid,
  user_id      uuid not null references auth.users(id) default public.ideali_dono_atual()
);
create index if not exists fin_lotes_user_criado_idx on public.fin_lotes(user_id, criado_em desc);

-- ── Extratos anexados (historico) ─────────────────────────────
create table if not exists public.extratos_arquivos (
  id                    uuid primary key default gen_random_uuid(),
  lote_id               uuid references public.fin_lotes(id),
  cliente_reg           int not null references public.cadastro_clientes(reg),
  mes                   int not null check (mes between 0 and 11),
  ano                   int not null check (ano between 2020 and 2100),
  path                  text not null,
  hash_sha256           text not null check (hash_sha256 ~ '^[0-9a-f]{64}$'),
  nome_arquivo          text,
  tamanho_bytes         int,
  nome_lido             text,                     -- nome do cliente como veio no PDF
  total_lido            numeric,                  -- "Total de Servicos" do PDF
  saldo_anterior_lido   numeric,                  -- com sinal: > 0 = cliente devia
  saldo_anterior_sistema numeric,                 -- calculado na tela, so para conferencia
  valor_mes_sistema     numeric,                  -- valor_mes no momento da importacao
  divergente            boolean not null default false,
  decisao_divergencia   text check (decisao_divergencia in ('manter_sistema', 'usar_pdf')),
  leitor                text not null check (leitor in ('leitor', 'ia', 'manual')),
  confianca             numeric check (confianca between 0 and 1),
  ia_uso_id             uuid,
  situacao              text not null default 'anexado' check (situacao in ('anexado', 'substituido', 'desfeito')),
  antes_extrato_url     text,                     -- estado do controle_mensal antes (para desfazer)
  antes_extrato_path    text,
  antes_valor_mes       numeric,
  criou_linha           boolean not null default false,
  criado_em             timestamptz not null default now(),
  criado_por            uuid default auth.uid(),
  user_id               uuid not null references auth.users(id) default public.ideali_dono_atual()
);
create unique index if not exists extratos_arquivos_hash_unico
  on public.extratos_arquivos(user_id, hash_sha256) where situacao <> 'desfeito';
create index if not exists extratos_arquivos_cliente_mes_idx on public.extratos_arquivos(user_id, ano, mes, cliente_reg);

-- ── Envios por WhatsApp ───────────────────────────────────────
create table if not exists public.fin_envios (
  id                 uuid primary key default gen_random_uuid(),
  cliente_reg        int not null references public.cadastro_clientes(reg),
  mes                int not null check (mes between 0 and 11),
  ano                int not null,
  tipo               text not null check (tipo in ('extrato', 'recibo', 'cobranca')),
  canal              text not null default 'whatsapp',
  telefone           text,
  texto              text not null,
  extrato_arquivo_id uuid references public.extratos_arquivos(id),
  link_expira_em     timestamptz,
  criado_em          timestamptz not null default now(),
  criado_por         uuid default auth.uid(),
  user_id            uuid not null references auth.users(id) default public.ideali_dono_atual()
);
create index if not exists fin_envios_cliente_mes_idx on public.fin_envios(user_id, ano, mes, cliente_reg);

-- ── Uso da IA (limite diario de custo) ────────────────────────
create table if not exists public.fin_ia_uso (
  id            uuid primary key default gen_random_uuid(),
  quando        timestamptz not null default now(),
  tipo          text not null check (tipo in ('extrato', 'comprovante')),
  modelo        text not null,
  tokens_in     int not null default 0,
  tokens_out    int not null default 0,
  custo_usd     numeric not null default 0,
  ok            boolean,                         -- null = leitura em andamento (custo_usd = reserva)
  erro          text,
  user_id       uuid not null references auth.users(id) default public.ideali_dono_atual()
);
create index if not exists fin_ia_uso_user_quando_idx on public.fin_ia_uso(user_id, quando desc);

-- ── Apelidos (nome lido -> cliente) ───────────────────────────
create table if not exists public.apelidos_pagador (
  id           uuid primary key default gen_random_uuid(),
  origem       text not null default 'comprovante' check (origem in ('extrato', 'comprovante')),
  apelido_norm text not null,                     -- sem acento, minusculo, sem "Dr."/"Dra."
  apelido      text not null,                     -- como apareceu no documento
  cliente_reg  int not null references public.cadastro_clientes(reg),
  usos         int not null default 1,
  criado_em    timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  user_id      uuid not null references auth.users(id) default public.ideali_dono_atual(),
  unique (user_id, origem, apelido_norm)
);

-- ── Auditoria ─────────────────────────────────────────────────
create table if not exists public.fin_auditoria (
  id            bigint generated always as identity primary key,
  quando        timestamptz not null default now(),
  usuario_id    uuid,
  usuario_email text,
  tabela        text not null,
  registro_id   text,
  acao          text not null,
  antes         jsonb,
  depois        jsonb,
  lote_id       uuid,
  user_id       uuid references auth.users(id)
);
create index if not exists fin_auditoria_user_quando_idx on public.fin_auditoria(user_id, quando desc);
create index if not exists fin_auditoria_lote_idx on public.fin_auditoria(lote_id) where lote_id is not null;

-- ── Regras de acesso: so o dono, em todas as tabelas novas ────
do $$
declare t text;
begin
  foreach t in array array['saldo_abertura_clientes', 'fin_config', 'fin_lotes', 'extratos_arquivos',
                           'fin_envios', 'fin_ia_uso', 'apelidos_pagador']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('drop policy if exists "dono acessa tudo" on public.%I', t);
    execute format('create policy "dono acessa tudo" on public.%I for all to authenticated
                    using (public.ideali_e_dono() and user_id = auth.uid())
                    with check (public.ideali_e_dono() and user_id = auth.uid())', t);
  end loop;
end $$;

-- Auditoria: o dono so LE; quem grava e o gatilho (ninguem altera nem apaga pelo app)
alter table public.fin_auditoria enable row level security;
revoke all on public.fin_auditoria from anon, authenticated;
grant select on public.fin_auditoria to authenticated;
drop policy if exists "dono le" on public.fin_auditoria;
create policy "dono le" on public.fin_auditoria for select to authenticated
  using (public.ideali_e_dono() and user_id = auth.uid());

-- ── Gatilho de auditoria ──────────────────────────────────────
-- Grava antes/depois de cada mudanca. Ignora update que so mexeu em updated_at.
-- O lote vem de set_config('ideali.lote', ...) feito pelas funcoes de importacao.
create or replace function public.fin_auditar()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_antes  jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  v_depois jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  v_lote   text  := nullif(current_setting('ideali.lote', true), '');
begin
  if tg_op = 'UPDATE' and (v_antes - 'updated_at' - 'atualizado_em') = (v_depois - 'updated_at' - 'atualizado_em') then
    return null;
  end if;
  insert into fin_auditoria (usuario_id, usuario_email, tabela, registro_id, acao, antes, depois, lote_id, user_id)
  values (auth.uid(), auth.jwt() ->> 'email', tg_table_name,
          coalesce(v_depois ->> 'id', v_antes ->> 'id', v_depois ->> 'user_id'),
          lower(tg_op), v_antes, v_depois, v_lote::uuid,
          coalesce((v_depois ->> 'user_id')::uuid, (v_antes ->> 'user_id')::uuid));
  return null;
end;
$$;
revoke execute on function public.fin_auditar() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['controle_mensal', 'pagamento_aportes', 'saldo_abertura_clientes', 'fin_config',
                           'extratos_arquivos', 'fin_envios', 'apelidos_pagador', 'fin_lotes']
  loop
    execute format('drop trigger if exists fin_auditoria on public.%I', t);
    execute format('create trigger fin_auditoria after insert or update or delete on public.%I
                    for each row execute function public.fin_auditar()', t);
  end loop;
end $$;

-- ── Anexar um extrato (chamada pela tela, depois do envio do PDF ao Storage) ──
-- Tudo numa transacao: confere duplicado (hash e cliente+mes), confere divergencia,
-- grava o link no controle_mensal e o historico. Se recusar, a tela apaga o PDF enviado.
create or replace function public.fin_anexar_extrato(p jsonb)
returns jsonb language plpgsql set search_path = public as $$
declare
  v_lote  uuid    := (p ->> 'lote_id')::uuid;
  v_reg   int     := (p ->> 'cliente_reg')::int;
  v_mes   int     := (p ->> 'mes')::int;
  v_ano   int     := (p ->> 'ano')::int;
  v_path  text    := p ->> 'path';
  v_hash  text    := lower(p ->> 'hash_sha256');
  v_total numeric := nullif(p ->> 'total_lido', '')::numeric;
  v_subst boolean := coalesce((p ->> 'substituir')::boolean, false);
  v_dec   text    := nullif(p ->> 'decisao_divergencia', '');
  v_cm    record;
  v_dup   record;
  v_div   boolean;
  v_id    uuid;
begin
  if not public.ideali_e_dono() then raise exception 'Somente o dono pode anexar extratos.'; end if;
  if v_mes is null or v_mes not between 0 and 11 then raise exception 'Mes invalido (0 a 11).'; end if;
  if v_path is null or v_path !~ ('^' || v_ano || '_' || v_mes || '/') then
    raise exception 'Caminho do arquivo nao bate com o mes (%_%/...).', v_ano, v_mes;
  end if;
  if not exists (select 1 from fin_lotes where id = v_lote and user_id = auth.uid() and desfeito_em is null) then
    raise exception 'Lote de importacao invalido.';
  end if;

  select e.cliente_reg, e.mes, e.ano into v_dup from extratos_arquivos e
   where e.user_id = auth.uid() and e.hash_sha256 = v_hash and e.situacao <> 'desfeito' limit 1;
  if found then
    raise exception 'DUPLICADO_HASH: este PDF ja foi anexado (cliente %, mes %/%).', v_dup.cliente_reg, v_dup.mes + 1, v_dup.ano;
  end if;

  select * into v_cm from controle_mensal c
   where c.cliente_reg = v_reg and c.mes = v_mes and c.ano = v_ano and c.user_id = auth.uid()
   order by c.created_at limit 1 for update;

  if found and v_cm.extrato_path is not null and not v_subst then
    raise exception 'JA_TEM_EXTRATO: cliente % ja tem extrato em %/%. Marque "substituir" para trocar.', v_reg, v_mes + 1, v_ano;
  end if;

  v_div := v_total is null or abs(v_total - coalesce(v_cm.valor_mes, 0)) > 0.004;
  if v_div and v_dec is null then
    raise exception 'DIVERGENCIA: total do extrato (%) diferente do valor do mes no sistema (%). Escolha manter ou usar o do PDF.',
      coalesce(v_total::text, 'nao lido'), coalesce(v_cm.valor_mes, 0);
  end if;
  if v_dec = 'usar_pdf' and v_total is null then raise exception 'Nao ha total lido para usar.'; end if;

  perform set_config('ideali.lote', v_lote::text, true);

  if v_cm.id is null then
    insert into controle_mensal (cliente_reg, mes, ano, valor_mes, extrato_url, extrato_path)
    values (v_reg, v_mes, v_ano, case when v_dec = 'usar_pdf' then v_total else 0 end, p ->> 'url', v_path);
  else
    update controle_mensal
       set extrato_url = p ->> 'url', extrato_path = v_path, updated_at = now(),
           valor_mes = case when v_dec = 'usar_pdf' then v_total else valor_mes end
     where id = v_cm.id;
    update extratos_arquivos set situacao = 'substituido'
     where user_id = auth.uid() and cliente_reg = v_reg and mes = v_mes and ano = v_ano and situacao = 'anexado';
  end if;

  insert into extratos_arquivos (lote_id, cliente_reg, mes, ano, path, hash_sha256, nome_arquivo, tamanho_bytes,
      nome_lido, total_lido, saldo_anterior_lido, saldo_anterior_sistema, valor_mes_sistema, divergente,
      decisao_divergencia, leitor, confianca, ia_uso_id, antes_extrato_url, antes_extrato_path, antes_valor_mes, criou_linha)
  values (v_lote, v_reg, v_mes, v_ano, v_path, v_hash, p ->> 'nome_arquivo', nullif(p ->> 'tamanho_bytes', '')::int,
      p ->> 'nome_lido', v_total, nullif(p ->> 'saldo_anterior_lido', '')::numeric,
      nullif(p ->> 'saldo_anterior_sistema', '')::numeric, coalesce(v_cm.valor_mes, 0), v_div,
      case when v_div then v_dec end, coalesce(p ->> 'leitor', 'leitor'), nullif(p ->> 'confianca', '')::numeric,
      nullif(p ->> 'ia_uso_id', '')::uuid, v_cm.extrato_url, v_cm.extrato_path, v_cm.valor_mes, v_cm.id is null)
  returning id into v_id;

  -- Aprende o nome como veio no PDF, quando a tela pedir
  if coalesce(p ->> 'apelido_norm', '') <> '' then
    insert into apelidos_pagador (origem, apelido_norm, apelido, cliente_reg)
    values ('extrato', p ->> 'apelido_norm', coalesce(p ->> 'nome_lido', p ->> 'apelido_norm'), v_reg)
    on conflict (user_id, origem, apelido_norm)
      do update set cliente_reg = excluded.cliente_reg, usos = apelidos_pagador.usos + 1, atualizado_em = now();
  end if;

  return jsonb_build_object('id', v_id, 'divergente', v_div);
end;
$$;
revoke execute on function public.fin_anexar_extrato(jsonb) from public, anon;
grant execute on function public.fin_anexar_extrato(jsonb) to authenticated;

-- ── Desfazer a ultima importacao ──────────────────────────────
-- Volta o controle_mensal ao estado de antes do lote e devolve os caminhos dos PDFs
-- do lote para a tela apagar do Storage. Recusa se algum mes foi mexido depois.
create or replace function public.fin_desfazer_ultimo_lote()
returns jsonb language plpgsql set search_path = public as $$
declare
  v_lote  record;
  g       record;
  v_cm    record;
  v_paths text[];
begin
  if not public.ideali_e_dono() then raise exception 'Somente o dono pode desfazer importacoes.'; end if;

  select * into v_lote from fin_lotes
   where user_id = auth.uid() and desfeito_em is null
   order by criado_em desc limit 1 for update;
  if not found then raise exception 'Nao ha importacao para desfazer.'; end if;
  if v_lote.tipo <> 'extratos' then raise exception 'A ultima importacao e de %; desfazer ainda nao disponivel para esse tipo.', v_lote.tipo; end if;

  perform set_config('ideali.lote', v_lote.id::text, true);

  for g in
    select e.cliente_reg, e.mes, e.ano,
           (array_agg(e.id order by e.criado_em))[1]              as primeiro_id,
           (array_agg(e.id order by e.criado_em desc))[1]         as ultimo_id
      from extratos_arquivos e
     where e.lote_id = v_lote.id and e.situacao <> 'desfeito'
     group by e.cliente_reg, e.mes, e.ano
  loop
    declare
      p extratos_arquivos;
      u extratos_arquivos;
    begin
      select * into p from extratos_arquivos where id = g.primeiro_id;
      select * into u from extratos_arquivos where id = g.ultimo_id;
      select * into v_cm from controle_mensal
       where cliente_reg = g.cliente_reg and mes = g.mes and ano = g.ano and user_id = auth.uid()
       order by created_at limit 1 for update;
      if not found or v_cm.extrato_path is distinct from u.path or v_cm.updated_at > u.criado_em then
        raise exception 'MUDOU_DEPOIS: o mes %/% do cliente % foi alterado depois da importacao. Desfaca a mao.', g.mes + 1, g.ano, g.cliente_reg;
      end if;
      update controle_mensal
         set extrato_url = p.antes_extrato_url, extrato_path = p.antes_extrato_path,
             valor_mes = coalesce(p.antes_valor_mes, 0), updated_at = now()
       where id = v_cm.id;
      -- o extrato que este lote tinha substituido volta a valer
      update extratos_arquivos set situacao = 'anexado'
       where user_id = auth.uid() and cliente_reg = g.cliente_reg and mes = g.mes and ano = g.ano
         and situacao = 'substituido' and path = p.antes_extrato_path
         and (lote_id is distinct from v_lote.id);
    end;
  end loop;

  select coalesce(array_agg(path), '{}') into v_paths from extratos_arquivos where lote_id = v_lote.id and situacao <> 'desfeito';
  update extratos_arquivos set situacao = 'desfeito' where lote_id = v_lote.id;
  update fin_lotes set desfeito_em = now(), desfeito_por = auth.uid() where id = v_lote.id;

  return jsonb_build_object('lote_id', v_lote.id, 'paths', to_jsonb(v_paths));
end;
$$;
revoke execute on function public.fin_desfazer_ultimo_lote() from public, anon;
grant execute on function public.fin_desfazer_ultimo_lote() to authenticated;

-- ── Reservar uma leitura da IA (mesmo padrao do ia_consumir do Ideali CAD) ──
-- Trava por dono + dia de Brasilia, confere o limite de custo e de quantidade e ja
-- grava a linha em fin_ia_uso com o custo estimado (ok = null). A Edge Function
-- troca pelo custo real no fim. Assim leituras em paralelo (lote) nao furam o limite;
-- se a funcao cair no meio, a reserva continua contando (fica do lado seguro).
create or replace function public.fin_ia_consumir(p_tipo text, p_modelo text, p_reserva_usd numeric)
returns jsonb language plpgsql set search_path = public as $$
declare
  v_ini    timestamptz := ((now() at time zone 'America/Sao_Paulo')::date)::timestamp at time zone 'America/Sao_Paulo';
  v_cfg    fin_config;
  v_gasto  numeric;
  v_n      int;
  v_id     uuid;
begin
  if not public.ideali_e_dono() then raise exception 'Somente o dono pode usar a leitura por IA.'; end if;
  perform pg_advisory_xact_lock(hashtext('fin_ia_' || auth.uid()::text));

  select * into v_cfg from fin_config where user_id = auth.uid();
  select coalesce(sum(custo_usd), 0), count(*) into v_gasto, v_n
    from fin_ia_uso where user_id = auth.uid() and quando >= v_ini;

  if coalesce(v_cfg.ia_limite_diario_usd, 0) <= 0 then
    return jsonb_build_object('ok', false, 'motivo', 'desligada');
  end if;
  if v_n >= coalesce(v_cfg.ia_max_leituras_dia, 200) then
    return jsonb_build_object('ok', false, 'motivo', 'quantidade', 'gasto', v_gasto, 'n', v_n);
  end if;
  if v_gasto + greatest(p_reserva_usd, 0) > v_cfg.ia_limite_diario_usd then
    return jsonb_build_object('ok', false, 'motivo', 'custo', 'gasto', v_gasto,
                              'limite', v_cfg.ia_limite_diario_usd);
  end if;

  insert into fin_ia_uso (tipo, modelo, custo_usd, ok)
  values (p_tipo, p_modelo, greatest(p_reserva_usd, 0), null)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'gasto', v_gasto, 'n', v_n + 1);
end;
$$;
revoke execute on function public.fin_ia_consumir(text, text, numeric) from public, anon;
grant execute on function public.fin_ia_consumir(text, text, numeric) to authenticated;

-- ── Bucket de extratos: privado, so PDF, ate 5 MB ─────────────
-- (ja era privado desde a 045; aqui fica registrado junto com o limite)
update storage.buckets
   set public = false, file_size_limit = 5242880, allowed_mime_types = array['application/pdf']
 where id = 'extratos';

-- Configuracao inicial do dono
insert into public.fin_config (user_id)
select dono_id from public.ideali_config where id and dono_id is not null
on conflict (user_id) do nothing;
