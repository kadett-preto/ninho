import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { decodeBase64Url } from "@std/encoding/base64url";
import { encodeHex } from "@std/encoding/hex";

// Ninho — Fase 4.5: preview de convite (sem consumir).
// IDEA.md §5.3 + §7.3.
//
// Fluxo:
//  1. Convidado autenticado envia token claro recebido por link/QR.
//  2. Token foi gerado em `create-invite` como base64url de 32 bytes — aqui
//     desfazemos a codificação e calculamos sha-256 dos mesmos bytes.
//  3. RPC `preview_invite(token_hash)` valida o convite e retorna
//     metadados do ninho (nome, n membros, n cômodos, streak, already_member).
//
// Não logamos token nem hash. Erros do RPC viram códigos HTTP genéricos
// (404/400/429/401) para não vazar diferenças entre estados do convite.

type RpcResult = {
  environment_id: string;
  environment_name: string;
  environment_created_at: string;
  member_count: number;
  member_names: string[];
  room_count: number;
  environment_streak: number;
  already_member: boolean;
};

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

  const token = typeof body.token === "string" ? body.token.trim() : "";
  if (token.length === 0 || token.length > 256) {
    return json({ error: "Token inválido" }, 400);
  }

  let tokenBytes: Uint8Array;
  try {
    tokenBytes = decodeBase64Url(token);
  } catch (_) {
    return json({ error: "Token inválido" }, 400);
  }
  if (tokenBytes.length < 16) {
    return json({ error: "Token inválido" }, 400);
  }

  const hashBuffer = await crypto.subtle.digest("SHA-256", tokenBytes);
  const tokenHash = encodeHex(new Uint8Array(hashBuffer));

  const { data, error } = await supabase.rpc("preview_invite", {
    p_token_hash: tokenHash,
  });

  if (error) {
    console.error("preview_invite failed", { code: error.code });
    const status =
      error.code === "28000"
        ? 401
        : error.code === "54000"
        ? 429
        : error.code === "42704"
        ? 404
        : error.code === "22023"
        ? 400
        : 500;
    return json({ error: error.message, code: error.code }, status);
  }

  const result = data as RpcResult;
  return json({
    environmentId: result.environment_id,
    environmentName: result.environment_name,
    environmentCreatedAt: result.environment_created_at,
    memberCount: result.member_count,
    memberNames: result.member_names,
    roomCount: result.room_count,
    environmentStreak: result.environment_streak,
    alreadyMember: result.already_member,
  });
});
