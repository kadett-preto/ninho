# Key rotation runbook — Ninho

> Procedimento para rotacionar segredos críticos (§7.7 do IDEA.md).
> Releia antes/depois de qualquer incidente, troca de membro com acesso,
> ou job de hardening de release.

---

## Princípios

- **Nenhuma chave no repo.** Auditar com `git log -p -- .env` e `grep -rE "(SECRET|PRIVATE_KEY|service_role|sk_live_)" --include="*.json" --include="*.ts"` antes de qualquer commit.
- **Rotacionar em 4 lugares por chave**: provedor (gera nova) → cofre (atualiza) → consumidor (lê) → revoga antiga. Pular a revogação é o erro mais comum.
- **Janela curta**: chave nova convive com antiga apenas o tempo do redeploy. Acima de 24h, abrir incidente.
- **Pós-rotação**: confirmar com curl/integration que a nova chave funciona ANTES de revogar a antiga.

---

## Inventário (jan/2026)

| Chave | Provedor | Cofre | Consumidor | Risco |
|---|---|---|---|---|
| Supabase `anon_key` | Supabase project | `.env` local + GitHub Secrets + `assets/.env` | Flutter client | Médio — pública por design, mas se vazar com RLS frouxo expõe tudo |
| Supabase `service_role_key` | Supabase project | `supabase secrets set` + GitHub Secrets | Edge Functions (cron, admin) | **Crítico** — bypassa RLS |
| Supabase DB password | Supabase project | `~/.config/supabase/access-token` (CLI) | `supabase db push` localmente | Alto |
| Supabase PAT (CLI) | Supabase user dashboard | `~/.config/supabase/access-token` + GitHub Secret se CI usar | `supabase link` / CLI | Alto |
| Anthropic API key | console.anthropic.com | `supabase secrets set ANTHROPIC_API_KEY` | `suggest-tasks`, `weekly-summary` | Médio — custo + abuso |
| Firebase service account | console.firebase.google.com | `supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON` | `_shared/fcm.ts` (FCM HTTP v1) | Alto — pode mandar push em nome do app |
| `google-services.json` | console.firebase.google.com | `android/app/` local (gitignored) | App Android build | Médio |
| `GoogleService-Info.plist` | console.firebase.google.com | `ios/Runner/` local (gitignored) | App iOS build | Médio |
| Sentry DSN | sentry.io | `.env` + GitHub Secret | Flutter `SentryService.init` | Baixo — público no app, abuso de quota possível |
| PostHog project key | posthog.com | `.env` + GitHub Secret | Flutter `PosthogService.init` | Baixo |
| Google OAuth client | console.cloud.google.com | Supabase Auth → provider config | Login Web/Android | Médio |

---

## Procedimento por chave

### Supabase `service_role` (CRÍTICO)

1. Supabase Dashboard → Project Settings → API → "Generate new secret".
2. Copie a chave nova.
3. Atualize em **paralelo**:
   - GitHub repo settings → Secrets → `SUPABASE_SERVICE_ROLE_KEY`.
   - `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<nova>` (afeta TODAS as Edge Functions ao próximo deploy).
4. `supabase functions deploy` para todas as funções que usam (`weekly-summary`, `send-task-reminders`, `notify-trigger`).
5. Smoke: chamar cada Edge Function com curl e validar 200/expected.
6. No Dashboard, "Revoke previous" — só depois das smokes verdes.

**Tempo de janela**: ≤ 15 min em produção.

### Anthropic API key

1. console.anthropic.com → API Keys → "Create key" (escopo: Workspace Ninho).
2. `supabase secrets set ANTHROPIC_API_KEY=<nova>`.
3. `supabase functions deploy suggest-tasks weekly-summary`.
4. Smoke: invocar Edge Function que chama Claude (com `USE_AI=true`) e ver resposta válida.
5. Revogar chave antiga no console Anthropic.

### Firebase service account

1. console.firebase.google.com → Project Settings → Service accounts → "Generate new private key".
2. Salva JSON local (NÃO commitar).
3. `cat key.json | base64 | supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON=...` (formato base64 single-line se a função decodifica; verifique `_shared/fcm.ts`).
4. `supabase functions deploy notify-trigger send-task-reminders`.
5. Smoke: trigger evento `feed_photo` ou `streak_broken` e verificar entrega.
6. No console Firebase, deletar key antiga.

### `google-services.json` / `GoogleService-Info.plist`

Normalmente NÃO rotaciona — vincula projeto Firebase ao bundle. Substituir só ao migrar projeto Firebase.

### Sentry DSN

1. sentry.io → Settings → Projects → ninho-mobile → Client Keys (DSN) → "Generate new key".
2. Atualizar `.env` + GitHub Secret + Flutter build (`SENTRY_DSN`).
3. Recompilar release. DSN antiga continua aceitando até deletar.
4. Após 100% rollout, revogar a antiga.

### PostHog project key

Mesmo padrão da Sentry DSN.

### Google OAuth client

1. console.cloud.google.com → APIs & Services → Credentials → OAuth 2.0 Client IDs → editar.
2. Não rotacionar client_id (quebra logins existentes); rotacionar **secret** se for client confidential.
3. Atualizar em Supabase Auth → Providers → Google.

### Supabase PAT (acesso CLI)

1. Supabase dashboard → Account → Access tokens → "Revoke" o antigo, "Generate new" pro novo.
2. Local: `supabase login` com a nova token.
3. CI: atualizar `SUPABASE_ACCESS_TOKEN` em GitHub Secrets.

---

## Quando rotacionar

Disparadores obrigatórios:

- **Sempre**: troca de membro com acesso ao secrets vault.
- **Sempre**: incidente confirmado/suspeito de vazamento (commit acidental, log público, repo backup vazado).
- **Anualmente**: service_role + Anthropic + Firebase service account (calendário).
- **Pré-release**: Sentry DSN + PostHog se nunca rotacionados antes da publicação.

Disparadores opcionais:

- Mudança suspeita de uso (gasto de API fora do padrão).
- Auditoria externa.

---

## Pós-rotação

- Anotar data + chave + responsável em `docs/AUDIT_LOG.md` (não inclui valor da chave).
- Reabrir o `git grep` de segredos pra garantir que a nova não vazou.
- Atualizar `docs/THREAT_MODEL.md` se a mitigação mudou.
