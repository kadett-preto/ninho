// Ninho — Fase 11.10: testes negativos dos helpers de auth.
// Rodar com:
//   deno test supabase/functions/_shared/auth_test.ts
import { assertEquals } from "jsr:@std/assert@^1.0.0";
import {
  jsonResponse,
  preflightOrMethodGuard,
  requireAuthHeader,
} from "./auth.ts";

Deno.test("preflightOrMethodGuard: OPTIONS retorna ok 200", () => {
  const r = new Request("https://x", { method: "OPTIONS" });
  const out = preflightOrMethodGuard(r)!;
  assertEquals(out.status, 200);
});

Deno.test("preflightOrMethodGuard: GET retorna 405", async () => {
  const r = new Request("https://x", { method: "GET" });
  const out = preflightOrMethodGuard(r)!;
  assertEquals(out.status, 405);
  const body = await out.json();
  assertEquals(body.error, "Método não permitido");
});

Deno.test("preflightOrMethodGuard: POST passa (null)", () => {
  const r = new Request("https://x", { method: "POST" });
  const out = preflightOrMethodGuard(r);
  assertEquals(out, null);
});

Deno.test("requireAuthHeader: ausente retorna 401", async () => {
  const r = new Request("https://x", { method: "POST" });
  const out = requireAuthHeader(r);
  assertEquals(out.ok, false);
  if (!out.ok) {
    assertEquals(out.response.status, 401);
    const body = await out.response.json();
    assertEquals(body.error, "Sessão ausente");
  }
});

Deno.test("requireAuthHeader: vazio retorna 401", () => {
  const r = new Request("https://x", {
    method: "POST",
    headers: { Authorization: "   " },
  });
  const out = requireAuthHeader(r);
  assertEquals(out.ok, false);
});

Deno.test("requireAuthHeader: presente retorna header cru", () => {
  const r = new Request("https://x", {
    method: "POST",
    headers: { Authorization: "Bearer abc.def.ghi" },
  });
  const out = requireAuthHeader(r);
  assertEquals(out.ok, true);
  if (out.ok) assertEquals(out.header, "Bearer abc.def.ghi");
});

Deno.test("jsonResponse: serializa body + CORS", async () => {
  const r = jsonResponse({ hello: "world" }, 201);
  assertEquals(r.status, 201);
  assertEquals(r.headers.get("Content-Type"), "application/json");
  assertEquals(r.headers.get("Access-Control-Allow-Origin"), "*");
  const body = await r.json();
  assertEquals(body, { hello: "world" });
});
