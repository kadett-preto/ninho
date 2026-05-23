import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { sendFcm } from "../_shared/fcm.ts";

// Ninho — Fase 8.9 + 7.5: gatilhos de eventos.
//
// Disparado por outras Edge Functions / RPCs internas via service_role.
// Não é chamado pelo cliente diretamente.
//
// Eventos suportados:
//   - streak_broken: { environment_id, user_id, kind: 'user' | 'environment' }
//   - streak_risk:   { environment_id, user_id }
//   - task_transferred: { environment_id, task_id, from_user, to_user }
//   - new_member:    { environment_id, joined_user_id }
//   - feed_photo:    { environment_id, posted_by, task_id? }
//   - shop_purchase: { environment_id, buyer_id, item }

interface BasePayload {
  event: string;
  environment_id: string;
  // Eventos com targets explícitos ignoram o broadcast genérico.
  target_user_ids?: string[];
  // PII boundary: data extra pode conter ids mas nunca emails de outros
  // ninhos. Caller é responsável (§7.8).
  data?: Record<string, unknown>;
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });

// Templates por evento. Tom acolhedor (IDEA.md §7 produto).
function template(event: string, data?: Record<string, unknown>): {
  title: string;
  body: string;
} {
  switch (event) {
    case "streak_broken":
      return {
        title: "Sem pressão 🌿",
        body: "O streak resetou hoje. Recomeça leve amanhã — todo dia é novo.",
      };
    case "streak_risk":
      return {
        title: "Streak em risco",
        body: "Tem task pendente — quer cuidar antes de dormir?",
      };
    case "task_transferred":
      return {
        title: "Tarefa transferida ✨",
        body: "Você recebeu uma tarefa do ninho. Confere quando puder.",
      };
    case "new_member":
      return {
        title: "Novo morador no ninho",
        body: "Alguém entrou. Dê as boas-vindas ao abrir o app.",
      };
    case "feed_photo":
      return {
        title: "Foto nova no mural",
        body: "Tem registro novo no mural do ninho.",
      };
    case "shop_purchase":
      return {
        title: "Compra na loja",
        body: typeof data?.item === "string"
          ? `Alguém comprou: ${(data.item as string).slice(0, 60)}.`
          : "Nova movimentação na loja.",
      };
    default:
      return {
        title: "Atualização do ninho",
        body: "Tem novidade no app.",
      };
  }
}

// Resolve quais usuários do ninho recebem. Default: todos membros ativos
// menos quem disparou (se houver). Eventos podem passar target_user_ids
// para focar (e.g. streak_broken só notifica o próprio usuário).
async function resolveTargets(
  client: SupabaseClient,
  envId: string,
  explicit?: string[],
): Promise<string[]> {
  if (explicit && explicit.length > 0) return explicit;
  const { data } = await client
    .from("environment_members")
    .select("user_id")
    .eq("environment_id", envId)
    .is("left_at", null);
  return (data ?? []).map((r) => r.user_id as string);
}

async function dispatch(
  client: SupabaseClient,
  payload: BasePayload,
) {
  const targets = await resolveTargets(
    client,
    payload.environment_id,
    payload.target_user_ids,
  );
  const tpl = template(payload.event, payload.data);
  let sent = 0;

  for (const uid of targets) {
    // Respeita preferências por evento.
    const { data: prefs } = await client
      .from("notification_preferences")
      .select(
        "push_enabled, event_task_transferred, event_new_member, event_feed_photo, event_streak_risk, event_streak_broken, event_shop_purchase",
      )
      .eq("user_id", uid)
      .maybeSingle();
    if (!prefs || !prefs.push_enabled) continue;

    const allowed = (() => {
      switch (payload.event) {
        case "streak_broken":
          return prefs.event_streak_broken;
        case "streak_risk":
          return prefs.event_streak_risk;
        case "task_transferred":
          return prefs.event_task_transferred;
        case "new_member":
          return prefs.event_new_member;
        case "feed_photo":
          return prefs.event_feed_photo;
        case "shop_purchase":
          return prefs.event_shop_purchase;
        default:
          return true;
      }
    })();
    if (!allowed) continue;

    const { data: tokens } = await client
      .from("push_tokens")
      .select("token")
      .eq("user_id", uid)
      .is("revoked_at", null);
    if (!tokens || tokens.length === 0) continue;

    for (const t of tokens) {
      const token = t.token as string;
      const result = await sendFcm({
        token,
        notification: { title: tpl.title, body: tpl.body },
        data: { event: payload.event, environment_id: payload.environment_id },
      });
      await client.from("notification_log").insert({
        environment_id: payload.environment_id,
        user_id: uid,
        task_id: typeof payload.data?.task_id === "string"
          ? payload.data.task_id
          : null,
        channel: "push",
        slot: "event",
        scheduled_for: new Date().toISOString(),
        sent_at: result.ok ? new Date().toISOString() : null,
        suppressed_reason: result.ok ? null : `fcm_status_${result.status}`,
        payload: { event: payload.event, title: tpl.title, body: tpl.body },
      });
      if (result.invalidateToken) {
        await client
          .from("push_tokens")
          .update({ revoked_at: new Date().toISOString() })
          .eq("token", token);
      }
      if (result.ok) sent++;
    }
  }

  return sent;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const auth = req.headers.get("authorization") ?? "";
  if (!auth.includes(SERVICE_ROLE)) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: BasePayload;
  try {
    payload = await req.json() as BasePayload;
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  if (!payload.event || !payload.environment_id) {
    return json({ error: "missing_fields" }, 400);
  }

  const client = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    const sent = await dispatch(client, payload);
    return json({ sent });
  } catch (e) {
    console.error("notify-trigger error", e);
    return json({ error: String(e) }, 500);
  }
});
