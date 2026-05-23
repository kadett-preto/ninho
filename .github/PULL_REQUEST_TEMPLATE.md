<!--
  Ninho — template de PR. Não delete sessões: deixe vazias se não se aplica.
  Veja `docs/SECURITY_REVIEW.md` para os checklists detalhados.
-->

## Resumo

<!-- 1–3 bullets do que muda + por quê. -->

## Tipo de mudança

- [ ] Feature
- [ ] Bug fix
- [ ] Refactor / cleanup
- [ ] Migration / schema
- [ ] Edge Function
- [ ] Infra / CI
- [ ] Docs

## IDEA.md / TASKS.md

<!-- Seção do IDEA.md (§X) e linha do TASKS.md afetadas. -->

## Como testar

<!-- Comandos `flutter test`, `supabase test db`, `deno test`, integration. -->

## Checklist de segurança

> Marque o que se aplica. Releia `IDEA.md §7` em dúvida.

- [ ] **RLS (§7.1):** tabelas com `environment_id` têm policies por papel; mudanças cobertas por pgTAP positivo + negativo (Alice/Bob/Carol).
- [ ] **Tabelas sensíveis (§7.1):** `invites`/`audit_log`/`notification_log`/`dust_ledger`/`task_transfers`/`streaks`/`push_tokens` continuam bloqueando INSERT/UPDATE/DELETE de client.
- [ ] **RPCs SECURITY DEFINER:** revalidam ownership/membership via `is_environment_*`, têm `set search_path = ''`, e `grant execute ... to authenticated` explícito (revoke de public/anon).
- [ ] **Edge Functions:** validam auth header + `auth.getUser()` antes de chamar RPC; usam helpers de `supabase/functions/_shared/` para parsing e auth.
- [ ] **Convites (§7.3):** token ≥128 bits, hash no DB, TTL respeitado, one-time use validado em pgTAP.
- [ ] **Storage (§7.4):** signed URLs com TTL curto, validação tipo/tamanho, EXIF strip antes do upload.
- [ ] **Prompt injection (§7.6):** dados do usuário entram como variável JSON nunca interpolada; system prompt cobre rótulo opaco + anti-jailbreak; snapshot test atualizado.
- [ ] **PII / logs (§7.5, §7.8):** nada de nome/email/título de tarefa em logs ou payloads de IA; metadata de audit usa flags ou hash quando necessário.
- [ ] **Segredos (§7.7):** nenhum secret no diff (`.env`, `google-services.json`, `service-account*.json` continuam fora do repo).
- [ ] **Audit log (§7.5):** ações sensíveis novas escrevem em `audit_log` (RPC direto ou via trigger `audit_*_change`).

## Checklist de qualidade

- [ ] `flutter analyze` limpo.
- [ ] `flutter test` verde (com testes novos cobrindo a mudança).
- [ ] `supabase test db` verde (se houve mudança em migrations/tests/config).
- [ ] `deno test supabase/functions/_shared/` verde (se mudou helpers ou validações).
- [ ] Integration test em device real (Galaxy S24) executado para mudanças de UI críticas.
- [ ] `TASKS.md` atualizado: status (`[x]`/`[~]`/`[!]`) + entrada no histórico com data.
- [ ] Diff reviewed e copy em pt-BR (tom acolhedor).

## Notas para a próxima sessão

<!-- Sub-tasks descobertas, débito técnico, follow-ups. -->
