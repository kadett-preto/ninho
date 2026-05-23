// Ninho — validações comuns para Edge Functions.
//
// Centraliza parsing/sanitização que toda função usa antes de
// invocar RPC. Manter aqui evita duplicação e dá superfície estável
// para testes negativos (§8.5 / Fase 11.10).

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function parseUuid(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return UUID_RE.test(value) ? value : null;
}

export type ParseResult<T> =
  | { ok: true; value: T }
  | { ok: false; error: string };

// TTL em dias para convites (§7.3 — 1-30, default 7).
export function parseInviteTtl(value: unknown): ParseResult<number> {
  if (value == null) return { ok: true, value: 7 };
  if (typeof value !== "number" || !Number.isInteger(value)) {
    return { ok: false, error: "ttlDays inválido" };
  }
  if (value < 1 || value > 30) {
    return { ok: false, error: "ttlDays fora do intervalo" };
  }
  return { ok: true, value };
}

// Nome de ninho — trim + cap 60 chars (§5.2).
export function parseEnvironmentName(value: unknown): ParseResult<string> {
  if (typeof value !== "string") return { ok: false, error: "nome inválido" };
  const trimmed = value.trim();
  if (trimmed.length === 0) return { ok: false, error: "nome obrigatório" };
  if (trimmed.length > 60) return { ok: true, value: trimmed.slice(0, 60) };
  return { ok: true, value: trimmed };
}

// Timezone IANA básico (formato `Region/City`; valida superfície, não
// catálogo).
export function parseTimezone(value: unknown): ParseResult<string> {
  if (typeof value !== "string") {
    return { ok: false, error: "timezone inválido" };
  }
  const re = /^[A-Za-z]+\/[A-Za-z_]+$/;
  if (!re.test(value)) return { ok: false, error: "timezone inválido" };
  return { ok: true, value };
}

// Token de convite codificado em base64url (§7.3 — 32 bytes => ~43 chars).
// Aceitamos faixa segura para aceitar variações futuras de tamanho.
export function parseInviteToken(value: unknown): ParseResult<string> {
  if (typeof value !== "string") {
    return { ok: false, error: "token inválido" };
  }
  if (value.length < 16 || value.length > 256) {
    return { ok: false, error: "tamanho de token inesperado" };
  }
  const re = /^[A-Za-z0-9_-]+$/;
  if (!re.test(value)) return { ok: false, error: "token mal formado" };
  return { ok: true, value };
}

// Mapeia erro de RPC para status HTTP coerente.
export function statusForRpcCode(code: string | undefined): number {
  switch (code) {
    case "42501":
      return 403;
    case "28000":
      return 401;
    case "22023":
      return 400;
    case "23503":
      return 400;
    case "54000":
      return 429;
    default:
      return 500;
  }
}
