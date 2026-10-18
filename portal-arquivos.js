/* ================================================================
   portal-arquivos.js — Arquivos do bucket "casos" nos portais
   (cliente e cadista). Conversa com a Edge Function portal-arquivos,
   que confere a sessão do portal e devolve links assinados.

   Imita a parte de storage do supabase-js que os portais já usavam
   (upload / list / createSignedUrl / remove), pra mexer pouco no código.
   Precisa de `sb` (cliente supabase com a chave pública) já criado.
   ================================================================ */
function portalArquivos(tipo, sessaoToken, casoId) {
  var urls = {};

  async function chamar(corpo) {
    var r = await sb.functions.invoke('portal-arquivos', {
      body: Object.assign({ tipo: tipo, sessao: sessaoToken, caso_id: casoId || null }, corpo)
    });
    if (r.error) {
      var msg = '';
      try { msg = (await r.error.context.json()).erro; } catch (e) {}
      return { data: null, error: { message: msg || r.error.message || 'Erro ao acessar arquivos' } };
    }
    return { data: r.data, error: null };
  }

  var bucket = {
    upload: async function (caminho, arquivo) {
      var r = await chamar({ acao: 'enviar', caminho: caminho });
      if (r.error) return r;
      return sb.storage.from('casos').uploadToSignedUrl(r.data.caminho, r.data.token, arquivo);
    },
    list: async function (pasta) {
      var r = await chamar({ acao: 'listar', pasta: pasta });
      if (r.error) return r;
      var lista = (r.data.arquivos || []).map(function (a) {
        if (!a.pasta) urls[r.data.pasta + '/' + a.name] = a.url;
        return { name: a.name, id: a.pasta ? null : a.id, metadata: a.metadata || null, created_at: a.created_at || null };
      });
      return { data: lista, error: null };
    },
    createSignedUrl: async function (caminho) {
      if (urls[caminho]) return { data: { signedUrl: urls[caminho] }, error: null };
      var r = await chamar({ acao: 'ler', caminho: caminho });
      if (r.error) return r;
      return { data: { signedUrl: r.data.url }, error: null };
    },
    remove: async function (caminhos) {
      for (var i = 0; i < caminhos.length; i++) {
        var r = await chamar({ acao: 'excluir', caminho: caminhos[i] });
        if (r.error) return r;
      }
      return { data: caminhos, error: null };
    }
  };

  return {
    storage: { from: function () { return bucket; } },
    // Pasta permitida para esta sessão/caso (ex.: "12/uuid-do-caso")
    pasta: async function () {
      var r = await chamar({ acao: 'pasta' });
      if (r.error) throw new Error(r.error.message);
      return r.data.pasta;
    }
  };
}
