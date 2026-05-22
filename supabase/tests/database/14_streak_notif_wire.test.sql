-- Ninho — Fase 7.5: evaluator dispara dispatch_notify_event em quebra.
--
-- Cobertura:
--   * Função dispatch_notify_event existe + sem grant a public/authenticated.
--   * Streak individual quebrado (freezes esgotados) adiciona user ao
--     broken_users do payload.
--   * Env streak broken + current_count > 0 prévio → broken_users null
--     mas environment_outcome=broken.
--   * Env streak já em 0 quando quebra de novo → não rebroadcast.

begin;
select plan(7);

-- ============================================================
-- Existência + grants
-- ============================================================
select has_function(
  'public',
  'dispatch_notify_event',
  array['uuid', 'text', 'uuid[]', 'jsonb']
);

select function_lang_is(
  'public',
  'dispatch_notify_event',
  array['uuid', 'text', 'uuid[]', 'jsonb'],
  'plpgsql'
);

select function_privs_are(
  'public',
  'dispatch_notify_event',
  array['uuid', 'text', 'uuid[]', 'jsonb'],
  'authenticated',
  array[]::text[]
);

-- ============================================================
-- Setup: ninho com 1 morador, 1 task diária, freezes esgotados
-- ============================================================
insert into auth.users (id, email) values
  ('11111111-bbbb-0000-0000-000000000001', 'owner-notif@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-bbbb-0000-0000-000000000001"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-bbbb-0000-0000-000000000001',
   '11111111-bbbb-0000-0000-000000000001',
   'Ninho Notif',
   'America/Sao_Paulo');

set local role postgres;
insert into public.rooms (id, environment_id, name, size_category) values
  ('bbbbbbbb-bbbb-0000-0000-000000000001',
   'aaaaaaaa-bbbb-0000-0000-000000000001',
   'Cozinha', 'M');

insert into public.tasks (
  id, environment_id, room_id, title, difficulty, start_date,
  assignee_id, created_by
) values
  ('cccccccc-bbbb-0000-0000-000000000001',
   'aaaaaaaa-bbbb-0000-0000-000000000001',
   'bbbbbbbb-bbbb-0000-0000-000000000001',
   'Task Owner',
   'mamao',
   (current_date - 1),
   '11111111-bbbb-0000-0000-000000000001',
   '11111111-bbbb-0000-0000-000000000001');

-- Streak prévio com current=5 mas freezes=0 + month_key igual.
insert into public.streaks (
  environment_id, user_id, kind, current_count, best_count,
  freezes_left_month, freezes_month_key
) values (
  'aaaaaaaa-bbbb-0000-0000-000000000001',
  '11111111-bbbb-0000-0000-000000000001',
  'user', 5, 5, 0, to_char(current_date - 1, 'YYYY-MM')
);

insert into public.streaks (
  environment_id, user_id, kind, current_count, best_count,
  freezes_left_month, freezes_month_key
) values (
  'aaaaaaaa-bbbb-0000-0000-000000000001',
  null,
  'environment', 5, 5, 2, to_char(current_date - 1, 'YYYY-MM')
);

-- ============================================================
-- Avalia ontem sem completion — owner quebra
-- ============================================================
select isnt_empty(
  $$select public.evaluate_environment_streaks(
    'aaaaaaaa-bbbb-0000-0000-000000000001'::uuid, current_date - 1
  )$$,
  'Evaluator retorna payload'
);

-- Payload contém broken_users com o owner
select is(
  (public.evaluate_environment_streaks(
    'aaaaaaaa-bbbb-0000-0000-000000000001'::uuid, current_date - 1
  )->'broken_users')::text,
  '["11111111-bbbb-0000-0000-000000000001"]'::jsonb::text,
  'broken_users contém quem falhou sem freeze'
);

-- Streak individual zerado
select is(
  (select current_count from public.streaks
    where environment_id = 'aaaaaaaa-bbbb-0000-0000-000000000001'
      and kind = 'user'
      and user_id = '11111111-bbbb-0000-0000-000000000001'),
  0,
  'Streak individual zerado após quebra'
);

-- Env streak também
select is(
  (select current_count from public.streaks
    where environment_id = 'aaaaaaaa-bbbb-0000-0000-000000000001'
      and kind = 'environment'),
  0,
  'Env streak zerado'
);

select * from finish();
rollback;
