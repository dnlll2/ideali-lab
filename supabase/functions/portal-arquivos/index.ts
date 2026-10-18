// ================================================================
// portal-arquivos — arquivos do bucket privado "casos" para os portais
// Ideali Laboratório
//
// Substitui os JWTs caseiros (gerar_jwt_upload / gerar_jwt_leitura_cadista),
// que dependiam do JWT secret antigo do projeto. Aqui a função confere a
// sessão do portal (tabela portal_sessoes) e só então lista, gera link
// assinado de leitura/envio ou exclui — sempre dentro da pasta permitida:
//   cliente → {cliente_reg}/...            (só a própria pasta)
//   cadista → {cliente_reg}/{caso_id}/...  (só o caso atribuído a ele)
//
// Segredo: IDEALI_SECRET_KEY (chave secreta sb_secret_..., via `supabase secrets set`).
// Deploy: supabase functions deploy portal-arquivos --no-verify-jwt
// ================================================================
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const BUCKET = "casos";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("IDEALI_SECRET_KEY")!,
  { auth: { persistSession: false } },
);

function resp(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

function caminhoSeguro(p: unknown): string | null {
  if (typeof p !== "string" || !p || p.length > 500) return null;
  if (p.includes("..") || p.startsWith("/") || p.includes("\\")) return null;
  return p;
}

async function pastaPermitida(sessao: string, tipo: string, casoId?: string): Promise<string> {
  const { data: s } = await admin.from("portal_sessoes").select("reg")
    .eq("token", sessao).eq("tipo", tipo).gt("expira_em", new Date().toISOString()).maybeSingle();
  if (!s) throw new Error("Sessão expirada ou inválida. Faça login novamente.");
  if (tipo === "cliente") return `${s.reg}/`;
  if (!casoId) throw new Error("Caso não informado.");
  const { data: o } = await admin.from("ordens_exocad").select("id, cliente_reg")
    .eq("id", casoId).eq("cadista_reg", s.reg).maybeSingle();
  if (!o) throw new Error("Caso não encontrado ou não atribuído a você.");
  if (o.cliente_reg == null) throw new Error("Este pedido não tem cliente vinculado — sem pasta de anexos.");
  return `${o.cliente_reg}/${o.id}/`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resp({ erro: "Método não permitido" }, 405);
  try {
    const b = await req.json();
    const tipo = b.tipo === "cadista" ? "cadista" : "cliente";
    if (typeof b.sessao !== "string" || !b.sessao) return resp({ erro: "Sessão ausente." }, 401);
    const base = await pastaPermitida(b.sessao, tipo, b.caso_id);
    const st = admin.storage.from(BUCKET);

    // Caminho pedido tem que ficar dentro da pasta permitida
    const dentro = (p: unknown) => {
      const c = caminhoSeguro(p);
      if (!c || !(c + "/").startsWith(base) && !c.startsWith(base)) throw new Error("Pasta não permitida.");
      return c;
    };

    switch (b.acao) {
      case "pasta":
        return resp({ pasta: base.replace(/\/$/, "") });
      case "listar": {
        const pasta = dentro(b.pasta ?? base.replace(/\/$/, ""));
        const { data, error } = await st.list(pasta, { limit: 1000 });
        if (error) throw error;
        const arquivos = [];
        for (const f of data ?? []) {
          if (!f.id) { arquivos.push({ name: f.name, pasta: true }); continue; }
          const s = await st.createSignedUrl(`${pasta}/${f.name}`, 3600);
          arquivos.push({ name: f.name, id: f.id, metadata: f.metadata, created_at: f.created_at, url: s.data?.signedUrl ?? null });
        }
        return resp({ pasta, arquivos });
      }
      case "ler": {
        const { data, error } = await st.createSignedUrl(dentro(b.caminho), 3600);
        if (error) throw error;
        return resp({ url: data.signedUrl });
      }
      case "enviar": {
        const { data, error } = await st.createSignedUploadUrl(dentro(b.caminho));
        if (error) throw error;
        return resp({ caminho: data.path, token: data.token });
      }
      case "excluir": {
        if (tipo !== "cadista") return resp({ erro: "Ação não permitida." }, 403);
        const { error } = await st.remove([dentro(b.caminho)]);
        if (error) throw error;
        return resp({ ok: true });
      }
      default:
        return resp({ erro: "Ação desconhecida." }, 400);
    }
  } catch (e) {
    return resp({ erro: (e as Error).message || "Erro" }, 400);
  }
});
