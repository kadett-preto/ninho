// Cliente mínimo do FCM HTTP v1 — IDEA.md §7.7 (sem SDK pesado em Edge,
// usamos JWT do service account assinado on-the-fly e POST direto).
//
// O service account JSON vem da env `FIREBASE_SERVICE_ACCOUNT_JSON`. Em
// staging/prod deve ser secret do Supabase; em dev local exporta via
// `.env`. Nunca commitar (§7.7).

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

interface FcmMessage {
  token: string;
  notification: { title: string; body: string };
  data?: Record<string, string>;
}

let cachedToken: { value: string; expiresAt: number } | null = null;

function loadServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON não configurado");
  }
  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
    throw new Error("service account JSON incompleto");
  }
  return parsed;
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.value;
  }
  const sa = loadServiceAccount();
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const b64 = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replaceAll("=", "")
      .replaceAll("+", "-")
      .replaceAll("/", "_");
  const data = `${b64(header)}.${b64(payload)}`;

  const pem = sa.private_key.replace(/\\n/g, "\n");
  const keyData = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(data),
    ),
  );
  const sigB64 = btoa(String.fromCharCode(...signature))
    .replaceAll("=", "")
    .replaceAll("+", "-")
    .replaceAll("/", "_");
  const jwt = `${data}.${sigB64}`;

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!resp.ok) {
    throw new Error(`Token FCM falhou: ${resp.status} ${await resp.text()}`);
  }
  const body = await resp.json() as { access_token: string; expires_in: number };
  cachedToken = {
    value: body.access_token,
    expiresAt: now + body.expires_in,
  };
  return body.access_token;
}

// Envia 1 mensagem. Retorna true se aceita pelo FCM, false se o token é
// inválido/desregistrado (para o caller revogar o token na tabela).
export async function sendFcm(message: FcmMessage): Promise<
  { ok: boolean; invalidateToken: boolean; status: number; bodyText?: string }
> {
  const sa = loadServiceAccount();
  const token = await getAccessToken();
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ message }),
    },
  );
  if (resp.ok) {
    return { ok: true, invalidateToken: false, status: resp.status };
  }
  const text = await resp.text();
  // FCM responde 404/UNREGISTERED ou 400/INVALID_ARGUMENT para tokens
  // mortos. Caller deve revogar.
  const invalidate = resp.status === 404 ||
    text.includes("UNREGISTERED") ||
    text.includes("INVALID_ARGUMENT");
  return {
    ok: false,
    invalidateToken: invalidate,
    status: resp.status,
    bodyText: text,
  };
}
