import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

type RoomInput = {
  name: unknown;
  sizeCategory?: unknown;
  size_category?: unknown;
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
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
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

  const name = parseRequiredString(body.name, 80);
  const timezone = parseRequiredString(body.timezone, 64);
  const rooms = parseRooms(body.rooms);

  if (!name.ok) return json({ error: "Nome do ninho inválido" }, 400);
  if (!timezone.ok) return json({ error: "Fuso horário inválido" }, 400);
  if (!rooms.ok) return json({ error: rooms.error }, 400);

  const { data, error } = await supabase.rpc("create_environment_with_rooms", {
    p_name: name.value,
    p_timezone: timezone.value,
    p_rooms: rooms.value,
  });

  if (error) {
    console.error("create_environment_with_rooms failed", {
      code: error.code,
      message: error.message,
    });
    return json({ error: error.message }, error.code === "22023" ? 400 : 500);
  }

  return json({
    environmentId: data.environment_id,
    rooms: data.rooms,
  });
});

function parseRequiredString(
  value: unknown,
  maxLength: number,
): { ok: true; value: string } | { ok: false } {
  if (typeof value !== "string") return { ok: false };
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maxLength) return { ok: false };
  return { ok: true, value: trimmed };
}

function parseRooms(
  value: unknown,
):
  | { ok: true; value: Array<{ name: string; size_category: string }> }
  | { ok: false; error: string } {
  if (!Array.isArray(value)) {
    return { ok: false, error: "Cômodos inválidos" };
  }
  if (value.length < 1 || value.length > 20) {
    return { ok: false, error: "Informe entre 1 e 20 cômodos" };
  }

  const rooms = [];
  for (const item of value as RoomInput[]) {
    const name = parseRequiredString(item.name, 80);
    const sizeRaw = item.sizeCategory ?? item.size_category;
    const size = typeof sizeRaw === "string" ? sizeRaw.trim().toUpperCase() : "";

    if (!name.ok) return { ok: false, error: "Nome de cômodo inválido" };
    if (!["P", "M", "G"].includes(size)) {
      return { ok: false, error: "Tamanho de cômodo inválido" };
    }
    rooms.push({ name: name.value, size_category: size });
  }

  return { ok: true, value: rooms };
}
