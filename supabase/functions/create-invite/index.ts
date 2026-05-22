import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { encodeBase64Url } from "@std/encoding/base64url";
import { encodeHex } from "@std/encoding/hex";

// Ninho — Fase 4.2: gera convite para um ninho.
// IDEA.md §5.3 (convite) + §7.3 (segurança).
//
// Fluxo:
//  1. Gera 32 bytes aleatórios (>=128 bits, §7.3) e codifica como base64url.
//     Esse é o token claro — entregue UMA vez para o owner colocar no link/QR.
//  2. Calcula sha-256 do token. Apenas o hash chega ao banco.
//  3. Chama RPC `create_invite(environment_id, token_hash, ttl_days)`, que
//     valida ownership via is_environment_owner() e insere com defense-in-depth
//     (a tabela `invites` bloqueia INSERT direto de cliente).

type RpcResult = { invite_id: string; expires_at: string };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método não permitido" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Sessão ausente" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey =
    Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    "";

  const supabase = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();
  if (authError || user == null) return json({ error: "Sessão inválida" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "JSON inválido" }, 400);
  }

  const environmentId = parseUuid(body.environmentId ?? body.environment_id);
  const ttlDays = parseTtl(body.ttlDays ?? body.ttl_days);

  if (!environmentId) return json({ error: "environmentId inválido" }, 400);
  if (!ttlDays.ok) return json({ error: ttlDays.error }, 400);

  // §7.3: token aleatório de 256 bits (32 bytes), codificado em base64url
  // para caber bem em URL/QR sem padding.
  const tokenBytes = crypto.getRandomValues(new Uint8Array(32));
  const token = encodeBase64Url(tokenBytes);
  const hashBuffer = await crypto.subtle.digest("SHA-256", tokenBytes);
  const tokenHash = encodeHex(new Uint8Array(hashBuffer));

  const { data, error } = await supabase.rpc("create_invite", {
    p_environment_id: environmentId,
    p_token_hash: tokenHash,
    p_ttl_days: ttlDays.value,
  });

  if (error) {
    console.error("create_invite failed", { code: error.code });
    const status = error.code === "42501"
      ? 403
      : error.code === "22023"
      ? 400
      : 500;
    return json({ error: error.message }, status);
  }

  const result = data as RpcResult;
  return json({
    inviteId: result.invite_id,
    token,
    expiresAt: result.expires_at,
  });
});

function parseUuid(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const re =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return re.test(value) ? value : null;
}

function parseTtl(value: unknown):
  | { ok: true; value: number }
  | { ok: false; error: string } {
  if (value == null) return { ok: true, value: 7 };
  if (typeof value !== "number" || !Number.isInteger(value)) {
    return { ok: false, error: "ttlDays inválido" };
  }
  if (value < 1 || value > 30) return { ok: false, error: "ttlDays fora do intervalo" };
  return { ok: true, value };
}
