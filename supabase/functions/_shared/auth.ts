// Ninho — helpers de autenticação para Edge Functions.
//
// Centraliza o handshake mínimo que toda função autenticada faz:
//   1. CORS preflight automático.
//   2. Exigência de `Authorization` header.
//   3. Validação via `supabase.auth.getUser()` antes de chamar RPC.
//
// Testes em `auth_test.ts` cobrem os caminhos negativos (sem auth /
// auth ruim / método errado), independentes de Supabase real.

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Rejeita métodos que não sejam POST/OPTIONS (todas as nossas funções
// são POST). Retorna null quando o handler deve continuar.
export function preflightOrMethodGuard(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Método não permitido" }, 405);
  }
  return null;
}

// Garante que existe Authorization header. Retorna o valor cru ou null
// (com Response 401) — não tenta validar a sessão via Supabase.
export function requireAuthHeader(
  req: Request,
): { ok: true; header: string } | { ok: false; response: Response } {
  const header = req.headers.get("Authorization");
  if (!header || header.trim() === "") {
    return {
      ok: false,
      response: jsonResponse({ error: "Sessão ausente" }, 401),
    };
  }
  return { ok: true, header };
}
