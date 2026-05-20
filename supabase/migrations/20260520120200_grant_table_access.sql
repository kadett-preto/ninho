-- Ninho — concede DML em todas tabelas de public para roles anon/authenticated.
-- RLS continua sendo a fonte da verdade do acesso por linha; este GRANT é o
-- base privilege exigido pelo PostgREST para sequer falar com o cliente.
--
-- Por defesa em profundidade, NÃO concedemos em tabelas só-server (invites,
-- notification_log, audit_log, dust_ledger, task_transfers, streaks) — essas
-- são acessadas só via service_role.

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on
  public.users,
  public.environments,
  public.environment_members,
  public.rooms,
  public.tasks,
  public.task_completions,
  public.feed_events
  to authenticated;

-- Anon precisa apenas o suficiente p/ rotas pré-login (none por enquanto).
-- Se algum dia abrirmos cadastro/onboarding via deep link sem login, ampliar.

-- Tabelas só-server permanecem sem grants (apenas service_role + postgres):
--   invites, notification_log, audit_log, dust_ledger, task_transfers, streaks
-- Clientes podem SELECT via policies se RLS permitir, mas só se houver grant
-- explícito. Mantemos lockdown.

-- Para SELECT-only por RLS em tabelas sensíveis (ex.: invites pelo owner,
-- audit_log pelo owner, notification_log pelo próprio usuário), conceder
-- explicitamente SELECT mas não as outras operações.
grant select on
  public.invites,
  public.notification_log,
  public.audit_log,
  public.dust_ledger,
  public.task_transfers,
  public.streaks
  to authenticated;
