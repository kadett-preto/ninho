-- Ninho — RLS lockdown das tabelas só-server: invites, audit_log,
-- notification_log, task_transfers, streaks, dust_ledger (IDEA.md §7.1, §7.3, §7.5).
--
-- Clientes (authenticated role) nunca escrevem nessas tabelas. Verificações:
--   - SELECT permitido apenas para os papéis específicos (owner ou própria linha).
--   - INSERT/UPDATE/DELETE como authenticated falha por ausência de policy.

begin;
select plan(14);

-- ---- Setup -----------------------------------------------------------------

insert into auth.users (id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
insert into public.users (id, display_name) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Alice'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bob');

insert into public.environments (id, owner_id, name, timezone) values
  ('eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Ninho Alice', 'America/Sao_Paulo');

-- Dado preexistente: simulamos um convite, um audit log e uma notificação
-- inseridos via service_role (postgres) — assim podemos testar SELECT.
insert into public.invites (environment_id, token_hash, created_by, expires_at)
  values ('eeeeeeee-1111-1111-1111-111111111111', 'hashfake', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '7 days');

insert into public.audit_log (environment_id, actor_id, action) values
  ('eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'environment.create');

insert into public.notification_log (environment_id, user_id, channel, slot, scheduled_for) values
  ('eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'push', 'morning', now());

insert into public.dust_ledger (environment_id, user_id, delta, reason) values
  ('eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 5, 'task_completed');

-- ---- Switch para role authenticated ---------------------------------------

set local role authenticated;

-- ---- invites ---------------------------------------------------------------

-- Alice é owner → vê convite.
set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select results_eq(
  'select count(*)::int from public.invites',
  array[1],
  'Owner vê convites do próprio ninho'
);

-- Bob não é membro → 0.
set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select results_eq(
  'select count(*)::int from public.invites',
  array[0],
  'Estranho não vê convites'
);

-- Bob (estranho) tenta inserir um convite forjado.
select throws_ok(
  $$insert into public.invites (environment_id, token_hash, created_by, expires_at) values ('eeeeeeee-1111-1111-1111-111111111111', 'evil', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', now() + interval '7 days')$$,
  '42501',
  'new row violates row-level security policy for table "invites"',
  'Cliente bloqueado de inserir invite (deve ser via Edge Function)'
);

-- Alice (owner) também bloqueada de inserir via cliente — só Edge Function.
set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select throws_ok(
  $$insert into public.invites (environment_id, token_hash, created_by, expires_at) values ('eeeeeeee-1111-1111-1111-111111111111', 'fromclient', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '7 days')$$,
  '42501',
  'new row violates row-level security policy for table "invites"',
  'Mesmo owner não consegue inserir invite pelo cliente'
);

-- ---- audit_log -------------------------------------------------------------

select results_eq(
  'select count(*)::int from public.audit_log',
  array[1],
  'Owner vê audit_log do próprio ninho'
);

set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select results_eq(
  'select count(*)::int from public.audit_log',
  array[0],
  'Estranho não vê audit_log'
);

select throws_ok(
  $$insert into public.audit_log (environment_id, actor_id, action) values ('eeeeeeee-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'fake')$$,
  '42501',
  'new row violates row-level security policy for table "audit_log"',
  'Cliente bloqueado de inserir audit_log (append-only via service_role)'
);

-- ---- notification_log ------------------------------------------------------

set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select results_eq(
  'select count(*)::int from public.notification_log where user_id = auth.uid()',
  array[1],
  'Usuário vê as próprias notificações'
);

set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select results_eq(
  'select count(*)::int from public.notification_log',
  array[0],
  'Outro usuário não vê notificações alheias'
);

select throws_ok(
  $$insert into public.notification_log (environment_id, user_id, channel, slot, scheduled_for) values ('eeeeeeee-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'push', 'morning', now())$$,
  '42501',
  'new row violates row-level security policy for table "notification_log"',
  'Cliente bloqueado de inserir notification_log'
);

-- ---- dust_ledger -----------------------------------------------------------

set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select results_eq(
  'select count(*)::int from public.dust_ledger',
  array[1],
  'Member vê dust_ledger do ambiente'
);

set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select results_eq(
  'select count(*)::int from public.dust_ledger',
  array[0],
  'Estranho não vê dust_ledger'
);

select throws_ok(
  $$insert into public.dust_ledger (environment_id, user_id, delta, reason) values ('eeeeeeee-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 999, 'free_dust')$$,
  '42501',
  'new row violates row-level security policy for table "dust_ledger"',
  'Cliente bloqueado de inserir dust_ledger (poeira só via service_role)'
);

-- ---- task_transfers --------------------------------------------------------

set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';

-- Precisa de uma task para FK; cria uma como postgres antes do switch.
-- Já trocamos role, mas a tabela tasks aceita member inserir.
insert into public.tasks (id, environment_id, title, difficulty, start_date, created_by)
  values ('aaaaaaaa-2222-2222-2222-222222222222',
          'eeeeeeee-1111-1111-1111-111111111111',
          'transferível', 'mamao', current_date,
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

select throws_ok(
  $$insert into public.task_transfers (environment_id, task_id, from_user_id, to_user_id, iso_year_week, cost_dust) values ('eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-W21', 30)$$,
  '42501',
  'new row violates row-level security policy for table "task_transfers"',
  'Cliente bloqueado de inserir task_transfers (Edge Function-only)'
);

select * from finish();
rollback;
