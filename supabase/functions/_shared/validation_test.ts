// Ninho — Fase 11.10: testes negativos das validações comuns.
// Rodar com:
//   deno test supabase/functions/_shared/validation_test.ts
import { assertEquals } from "jsr:@std/assert@^1.0.0";
import {
  parseEnvironmentName,
  parseInviteToken,
  parseInviteTtl,
  parseTimezone,
  parseUuid,
  statusForRpcCode,
} from "./validation.ts";

Deno.test("parseUuid: aceita uuid válido", () => {
  assertEquals(
    parseUuid("3f6e7e93-4a4f-4a8e-8b3a-1c4b9c4f8b9e"),
    "3f6e7e93-4a4f-4a8e-8b3a-1c4b9c4f8b9e",
  );
});

Deno.test("parseUuid: rejeita não-string", () => {
  assertEquals(parseUuid(null), null);
  assertEquals(parseUuid(undefined), null);
  assertEquals(parseUuid(123), null);
  assertEquals(parseUuid({}), null);
});

Deno.test("parseUuid: rejeita formato errado", () => {
  assertEquals(parseUuid(""), null);
  assertEquals(parseUuid("not-a-uuid"), null);
  assertEquals(parseUuid("3f6e7e93-4a4f-4a8e-8b3a-1c4b9c4f8b9"), null);
  assertEquals(parseUuid("3f6e7e93-4a4f-4a8e-8b3a-1c4b9c4f8b9e0"), null);
});

Deno.test("parseInviteTtl: default 7 quando null", () => {
  assertEquals(parseInviteTtl(null), { ok: true, value: 7 });
  assertEquals(parseInviteTtl(undefined), { ok: true, value: 7 });
});

Deno.test("parseInviteTtl: aceita 1..30", () => {
  assertEquals(parseInviteTtl(1), { ok: true, value: 1 });
  assertEquals(parseInviteTtl(30), { ok: true, value: 30 });
  assertEquals(parseInviteTtl(7), { ok: true, value: 7 });
});

Deno.test("parseInviteTtl: rejeita fora do range", () => {
  const a = parseInviteTtl(0);
  assertEquals(a.ok, false);
  const b = parseInviteTtl(31);
  assertEquals(b.ok, false);
  const c = parseInviteTtl(-1);
  assertEquals(c.ok, false);
});

Deno.test("parseInviteTtl: rejeita não-inteiro", () => {
  const a = parseInviteTtl(1.5);
  assertEquals(a.ok, false);
  const b = parseInviteTtl("7");
  assertEquals(b.ok, false);
});

Deno.test("parseEnvironmentName: trim + cap 60", () => {
  assertEquals(parseEnvironmentName("  Lar Doce Lar  "), {
    ok: true,
    value: "Lar Doce Lar",
  });
  const big = "x".repeat(80);
  const res = parseEnvironmentName(big);
  assertEquals(res.ok, true);
  if (res.ok) assertEquals(res.value.length, 60);
});

Deno.test("parseEnvironmentName: rejeita vazio/não-string", () => {
  assertEquals(parseEnvironmentName(""), {
    ok: false,
    error: "nome obrigatório",
  });
  assertEquals(parseEnvironmentName("   "), {
    ok: false,
    error: "nome obrigatório",
  });
  assertEquals(parseEnvironmentName(null), {
    ok: false,
    error: "nome inválido",
  });
});

Deno.test("parseTimezone: aceita formato IANA básico", () => {
  assertEquals(parseTimezone("America/Sao_Paulo"), {
    ok: true,
    value: "America/Sao_Paulo",
  });
  assertEquals(parseTimezone("Europe/Lisbon"), {
    ok: true,
    value: "Europe/Lisbon",
  });
});

Deno.test("parseTimezone: rejeita formato errado", () => {
  assertEquals(parseTimezone("UTC"), {
    ok: false,
    error: "timezone inválido",
  });
  assertEquals(parseTimezone(""), {
    ok: false,
    error: "timezone inválido",
  });
  assertEquals(parseTimezone(null), {
    ok: false,
    error: "timezone inválido",
  });
});

Deno.test("parseInviteToken: aceita base64url típico", () => {
  // ~43 chars (32 bytes base64url sem padding).
  const t = "AbC_123-defghijklmnopqrstuvwxyz_ABCDEFGHIJ-";
  const res = parseInviteToken(t);
  assertEquals(res.ok, true);
});

Deno.test("parseInviteToken: rejeita caracteres inválidos", () => {
  const a = parseInviteToken("not.allowed!");
  assertEquals(a.ok, false);
  const b = parseInviteToken("with space inside");
  assertEquals(b.ok, false);
});

Deno.test("parseInviteToken: rejeita curto/longo demais", () => {
  const a = parseInviteToken("short");
  assertEquals(a.ok, false);
  const b = parseInviteToken("a".repeat(300));
  assertEquals(b.ok, false);
});

Deno.test("statusForRpcCode mapeia códigos pgsql para HTTP", () => {
  assertEquals(statusForRpcCode("42501"), 403);
  assertEquals(statusForRpcCode("28000"), 401);
  assertEquals(statusForRpcCode("22023"), 400);
  assertEquals(statusForRpcCode("23503"), 400);
  assertEquals(statusForRpcCode("54000"), 429);
  assertEquals(statusForRpcCode(undefined), 500);
  assertEquals(statusForRpcCode("XYZ99"), 500);
});
