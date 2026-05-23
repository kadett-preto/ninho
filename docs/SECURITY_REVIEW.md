# Security review checklist — Ninho

> Detalhamento dos itens em `.github/PULL_REQUEST_TEMPLATE.md` (§7 do IDEA.md).
> Use como referência rápida antes de revisar/abrir PR.

---

## 1. RLS multi-tenant (§7.1)

**Pergunta crítica:** se outro morador (de outro ninho) tentar essa operação, o que acontece?

- Toda tabela com `environment_id` tem `enable row level security`.
- Policies por papel: `member` (select), `owner` (mutate sensível).
- Tabelas só-server (sem INSERT/UPDATE/DELETE client): `invites`, `audit_log`, `notification_log`, `dust_ledger`, `task_transfers`, `streaks`, `push_tokens`.
- pgTAP cobre positivo + negativo: criar `auth.users` Alice, Bob, Carol; provar que A não enxerga / não modifica dados de B; owner faz, member não faz.

**Antipadrão:** confiar só em `WHERE environment_id = X` no app. RLS é o último recurso — se cair, vaza dado entre ninhos.

---

## 2. RPCs SECURITY DEFINER

Sempre que precisar bypass de RLS:

- `language plpgsql security definer set search_path = ''` (evita catálogo do user).
- Primeiro check `if auth.uid() is null then raise exception ... using errcode = '28000';`.
- Segundo check `is_environment_owner(env)` ou `is_environment_member(env)`.
- `revoke all on function ... from public, anon;` + `grant execute on function ... to authenticated;` (ou só `service_role` se for cron-only).
- Audit log gravado antes do return.
- Parâmetros: prefixar com `p_` para evitar shadow de colunas.

---

## 3. Edge Functions

- Use helpers de `supabase/functions/_shared/`:
  - `auth.ts` → `preflightOrMethodGuard`, `requireAuthHeader`, `jsonResponse`.
  - `validation.ts` → `parseUuid`, `parseInviteTtl`, `parseEnvironmentName`, `parseTimezone`, `parseInviteToken`, `statusForRpcCode`.
  - `prompts.ts` → `systemPromptFor(kind, locale)` (12.3).
- Body sempre vem por `req.json()` num try/catch → 400 em parsing.
- Nunca chame Supabase admin (service_role) com input do user — passe pelo RPC SECURITY DEFINER.
- Log do erro do RPC só com `error.code` — nunca o `error.message` (pode ter PII).

---

## 4. Convites (§7.3)

- Token: 32 bytes `crypto.getRandomValues` → base64url (sem padding).
- Hash sha-256 (hex) é o que entra no banco. Token claro nunca persiste.
- TTL 1-30 dias, default 7.
- One-time use: `used_at`/`used_by` setados no aceite via `for update` lock.
- Rate-limit no DB: 10 tentativas/min/usuário via `audit_log`.

---

## 5. Storage (§7.4)

- Buckets privados: `room-photos`, `task-completion-photos`.
- Upload via `createSignedUploadUrl` → cliente recebe URL + token de uso único.
- Validação no cliente: tipo (JPG/PNG), tamanho (≤ 8 MB).
- Re-encode JPEG sem metadados antes do upload (EXIF strip).
- Paths sempre prefixados por `{environment_id}/...` — RLS no `storage.objects` confere folder.

---

## 6. Prompt injection (§7.6)

Cada Edge Function que chama Claude precisa:

- System prompt fixo, importado de `_shared/prompts.ts`.
- Dados do user entram como variável JSON (`JSON.stringify`), nunca interpolados em prosa.
- Snapshot test (`test/*_prompt_snapshot_test.dart`) trava o prompt + invariantes (rótulo opaco, anti-jailbreak, sem markdown, sem PII).
- Sanitização extra: strip control chars + truncate em campos texto (`name`, etc).
- Output revalidado server-side (rejeita JSON/markdown/multilinhas suspeitas; usa fallback estático).

---

## 7. PII boundary (§7.5, §7.8)

- IA recebe apenas: contadores, ids opacos, labels técnicos. Nunca: nomes, emails, títulos de tarefa cru, conteúdo de outros ninhos.
- Logs (`console.error`, Sentry): só `error.code`, ids opacos, contagens. Nada de payload do user.
- Audit log: usa flags (`difficulty_changed: bool`) ou hash (`md5(title)`) quando precisa "alguma referência" sem expor PII.
- PostHog: identifiedOnly + consent-gated. Autocapture/session-replay/lifecycle off.

---

## 8. Audit log (§7.5)

Toda ação sensível deixa rastro em `audit_log`:

- Owner muda env (rename, transfer ownership, archive, vacation toggle, store toggle).
- Membros entram/saem (invite accept, leave, removed).
- Storage / IA (suggest attempt, weekly summary publish).
- Triggers em `rooms` e `tasks` cobrem CRUD direto via PostgREST (Fase 11.9).
- `actor_id` pode ser `null` quando o evento é server-side (cron, trigger sem JWT).

---

## 9. Segredos (§7.7)

Nunca commitar:

- `.env`, `.env.*` (exceto `.env.example`).
- `google-services.json`, `GoogleService-Info.plist`.
- `*service-account*.json`, chaves Sentry/PostHog/Anthropic.

Onde vivem:

- Local dev: `.env` (ignored).
- CI: GitHub Secrets.
- Edge Functions: `supabase secrets set ...`.

Rotação: ver `docs/KEY_ROTATION.md`.

---

## 10. Threat model

Mapeamento ameaça → mitigação atualizado em `docs/THREAT_MODEL.md`. Releia antes de cada release.
