import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { encodeBase64Url } from "@std/encoding/base64url";
import { encodeHex } from "@std/encoding/hex";
import {
  jsonResponse,
  preflightOrMethodGuard,
  requireAuthHeader,
} from "../_shared/auth.ts";
import {
  parseInviteTtl,
  parseUuid,
  statusForRpcCode,
} from "../_shared/validation.ts";

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

Deno.serve(async (req) => {
  const guard = preflightOrMethodGuard(req);
  if (guard) return guard;

  const auth = requireAuthHeader(req);
  if (!auth.ok) return auth.response;

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    "";

  const supabase = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: auth.header } },
  });

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();
  if (authError || user == null) {
    return jsonResponse({ error: "Sessão inválida" }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return jsonResponse({ error: "JSON inválido" }, 400);
  }

  const environmentId = parseUuid(body.environmentId ?? body.environment_id);
  const ttlDays = parseInviteTtl(body.ttlDays ?? body.ttl_days);

  if (!environmentId) {
    return jsonResponse({ error: "environmentId inválido" }, 400);
  }
  if (!ttlDays.ok) return jsonResponse({ error: ttlDays.error }, 400);

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
    return jsonResponse({ error: error.message }, statusForRpcCode(error.code));
  }

  const result = data as RpcResult;
  return jsonResponse({
    inviteId: result.invite_id,
    token,
    expiresAt: result.expires_at,
  });
});
