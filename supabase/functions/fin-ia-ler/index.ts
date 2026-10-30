// ================================================================
// fin-ia-ler — leitura de extrato/comprovante pela IA (Claude)
// Ideali Laboratório · Central do Financeiro
//
// A chave da API fica SÓ aqui (segredo ANTHROPIC_API_KEY). A tela manda o
// arquivo em base64; nada é gravado no Storage antes da confirmação.
// Só o dono usa (confere ideali_e_dono() com a sessão de quem chamou).
// Limite diário de custo e de quantidade: fin_config (dia de Brasília). A reserva é
// feita no banco por fin_ia_consumir (com trava, padrão do ia_consumir do Ideali CAD),
// então leituras em paralelo não furam o limite. Cada chamada fica em fin_ia_uso.
// Não há texto livre aqui (só "extrato"/"comprovante"), então não precisa do filtro
// de assunto dos agentes: esse entra quando a Bia escrever avisos/cobranças (Módulo 3).
//
// Segredos: ANTHROPIC_API_KEY (supabase secrets set ANTHROPIC_API_KEY=...)
// Deploy:   supabase functions deploy fin-ia-ler --no-verify-jwt
//           (a função confere a sessão ela mesma, igual à portal-arquivos)
// ================================================================
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import Anthropic from "npm:@anthropic-ai/sdk";
import { zodOutputFormat } from "npm:@anthropic-ai/sdk/helpers/zod";
import { z } from "npm:zod@3";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function resp(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

// US$ por milhão de tokens (entrada, saída)
const PRECOS: Record<string, [number, number]> = {
  "claude-opus-5-5": [4, 20],
  "claude-sonnet-5-5": [2, 10],
  "claude-haiku-5-5": [0.10, 0.50],
};
const PUBLISHABLE_KEY = Deno.env.get("IDEALI_PUBLISHABLE_KEY") ?? "sb_publishable_oq7JWHoMvMqvjeaTDGHoqA_din8-sjJ";
const MAX_BYTES = 5 * 1024 * 1024;
// Custo estimado de uma leitura (1 a 2 páginas), reservado antes e trocado pelo real no fim
const RESERVA_USD: Record<string, number> = {
  "claude-opus-5-5": 0.05,
  "claude-sonnet-5-5": 0.03,
  "claude-haiku-5-5": 0.01,
};
const TIPOS = ["application/pdf", "image/jpeg", "image/png", "image/webp"];

const Extrato = z.object({
  cliente: z.string().describe("Nome do cliente exatamente como aparece no extrato; vazio se não houver"),
  periodo_inicio: z.string().describe("Data inicial do período, DD/MM/AAAA; vazio se não houver"),
  periodo_fim: z.string().describe("Data final do período, DD/MM/AAAA; vazio se não houver"),
  total_servicos: z.number().nullable().describe("Total de serviços do período, em reais, sempre positivo"),
  saldo_anterior: z.number().nullable().describe("Saldo anterior com sinal: positivo se o cliente devia, negativo se tinha crédito"),
  confianca: z.number().describe("De 0 a 1: certeza de que os campos acima estão corretos"),
  observacao: z.string().describe("Qualquer problema na leitura; vazio se nenhum"),
});

const Comprovante = z.object({
  valor: z.number().nullable().describe("Valor pago em reais"),
  data: z.string().describe("Data do pagamento, DD/MM/AAAA"),
  hora: z.string().describe("Hora do pagamento, HH:MM ou HH:MM:SS; vazio se não houver"),
  banco: z.string().describe("Banco ou instituição de quem pagou"),
  pagador: z.string().describe("Nome de quem pagou"),
  recebedor: z.string().describe("Nome de quem recebeu"),
  id_transacao: z.string().describe("ID da transação / identificador Pix (E2E); vazio se não houver"),
  confianca: z.number().describe("De 0 a 1: certeza de que os campos acima estão corretos"),
  observacao: z.string().describe("Qualquer problema na leitura; vazio se nenhum"),
});

const INSTRUCOES = {
  extrato:
    "Este é um extrato mensal de um laboratório de prótese dentária para um cliente (dentista ou clínica). " +
    "Leia o nome do cliente, o período, o \"Total de Serviços\" e o \"Saldo Anterior\". " +
    "Valores no formato brasileiro (1.234,56). Se um campo não existir, use vazio ou null. " +
    "Não invente valores: se não tiver certeza, diga em observacao e baixe a confiança.",
  comprovante:
    "Este é um comprovante de pagamento (Pix, TED ou boleto) feito por um cliente a um laboratório de prótese dentária. " +
    "Leia valor, data, hora, banco, nome de quem pagou, nome de quem recebeu e o ID da transação. " +
    "Valores no formato brasileiro (1.234,56). Se um campo não existir, use vazio ou null. " +
    "Não invente valores: se não tiver certeza, diga em observacao e baixe a confiança.",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resp({ erro: "Método não permitido" }, 405);

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return resp({ erro: "Sessão ausente." }, 401);
  // Cliente com a sessão de quem chamou: as regras de acesso (RLS) valem aqui também
  // (chave pública "publishable", a mesma do auth.js; a anon antiga foi revogada em 2026-10-17)
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, PUBLISHABLE_KEY, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false },
  });

  try {
    const { data: eDono, error: eErr } = await sb.rpc("ideali_e_dono");
    if (eErr || eDono !== true) return resp({ erro: "Somente o dono pode usar a leitura por IA." }, 403);

    const b = await req.json();
    const tipo = b.tipo === "comprovante" ? "comprovante" : b.tipo === "extrato" ? "extrato" : null;
    if (!tipo) return resp({ erro: "Tipo inválido." }, 400);
    const mime = String(b.media_type || "");
    if (!TIPOS.includes(mime)) return resp({ erro: "Tipo de arquivo não aceito." }, 400);
    const dados = String(b.dados_base64 || "");
    if (!dados || dados.length * 0.75 > MAX_BYTES) return resp({ erro: "Arquivo vazio ou maior que 5 MB." }, 400);

    const { data: cfg } = await sb.from("fin_config").select("ia_modelo").maybeSingle();
    const modelo = cfg?.ia_modelo && PRECOS[cfg.ia_modelo] ? cfg.ia_modelo : "claude-opus-5-5";

    const { data: lim, error: lErr } = await sb.rpc("fin_ia_consumir", { p_tipo: tipo, p_modelo: modelo, p_reserva_usd: RESERVA_USD[modelo] });
    if (lErr) return resp({ erro: "Não consegui conferir o limite da IA agora." }, 500);
    if (!lim?.ok) {
      if (lim?.motivo === "desligada") return resp({ erro: "IA desligada (limite 0 em Ajustes). Preencha à mão.", limite: true }, 429);
      const msg = lim?.motivo === "quantidade"
        ? `Limite diário de leituras da IA atingido (${lim.n}).`
        : `Limite diário da IA atingido (US$ ${Number(lim?.gasto ?? 0).toFixed(2)} de US$ ${Number(lim?.limite ?? 0).toFixed(2)}).`;
      return resp({ erro: msg + " Preencha à mão ou aumente o limite.", limite: true }, 429);
    }
    const usoId: string = lim.id;

    const bloco = mime === "application/pdf"
      ? { type: "document" as const, source: { type: "base64" as const, media_type: "application/pdf" as const, data: dados } }
      : { type: "image" as const, source: { type: "base64" as const, media_type: mime as "image/jpeg" | "image/png" | "image/webp", data: dados } };

    const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });
    let r;
    try {
      r = await client.messages.parse({
        model: modelo,
        max_tokens: 4000,
        output_config: { effort: "low", format: zodOutputFormat(tipo === "extrato" ? Extrato : Comprovante) },
        messages: [{ role: "user", content: [bloco, { type: "text", text: INSTRUCOES[tipo] }] }],
      });
    } catch (e) {
      await sb.from("fin_ia_uso").update({ custo_usd: 0, ok: false, erro: String((e as Error).message || e).slice(0, 500) }).eq("id", usoId);
      if (e instanceof Anthropic.RateLimitError) return resp({ erro: "IA ocupada agora. Tente de novo em instantes." }, 429);
      if (e instanceof Anthropic.APIError) return resp({ erro: `A IA recusou a leitura (${e.status}).` }, 502);
      throw e;
    }

    const [pIn, pOut] = PRECOS[modelo];
    const tIn = (r.usage.input_tokens || 0) + (r.usage.cache_creation_input_tokens || 0) + (r.usage.cache_read_input_tokens || 0);
    const tOut = r.usage.output_tokens || 0;
    const custo = (tIn * pIn + tOut * pOut) / 1e6;
    const recusou = r.stop_reason === "refusal";
    await sb.from("fin_ia_uso")
      .update({ tokens_in: tIn, tokens_out: tOut, custo_usd: custo, ok: !recusou && !!r.parsed_output, erro: recusou ? "refusal" : null })
      .eq("id", usoId);

    if (recusou || !r.parsed_output) return resp({ erro: "A IA não conseguiu ler este arquivo.", ia_uso_id: usoId }, 422);
    return resp({ leitura: r.parsed_output, modelo, custo_usd: custo, ia_uso_id: usoId });
  } catch (e) {
    return resp({ erro: (e as Error).message || "Erro" }, 400);
  }
});
