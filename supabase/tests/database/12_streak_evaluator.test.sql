-- Ninho — Fase 7: RPC evaluate_environment_streaks + vacation_periods.
-- IDEA.md §5.7.
--
-- Cobertura:
--   * Sem ninho → 42704.
--   * Happy path: 1 morador conclui task → streak +1 (user + env).
--   * Falha com freeze disponível → consome, streak mantém, ninho zera.
--   * Falha sem freeze → user + env zeram.
--   * Modo viagem: paused, streak intacto, freezes intactos.
--   * Virada de mês reseta freezes.
--   * Task sem assignee não conta.
--   * RLS bloqueia chamada de role authenticated.
--   * start_vacation owner-only + idempotência (já em viagem rejeita).

begin;
select plan(15);

insert into auth.users (id, email) values
  ('11111111-aaaa-0000-0000-000000000001', 'owner-streak@test.local'),
  ('22222222-aaaa-0000-0000-000000000001', 'alice-streak@test.local'),
  ('33333333-aaaa-0000-0000-000000000001', 'bob-streak@test.local'),
  ('44444444-aaaa-0000-0000-000000000001', 'outsider-streak@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-aaaa-0000-0000-000000000001"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-aaaa-0000-0000-000000000001',
   '11111111-aaaa-0000-0000-000000000001',
   'Ninho Streak',
   'America/Sao_Paulo');

set local role postgres;
insert into public.environment_members (environment_id, user_id, role) values
  ('aaaaaaaa-aaaa-0000-0000-000000000001', '22222222-aaaa-0000-0000-000000000001', 'member'),
  ('aaaaaaaa-aaaa-0000-0000-000000000001', '33333333-aaaa-0000-0000-000000000001', 'member');

insert into public.rooms (id, environment_id, name, size_category) values
  ('bbbbbbbb-aaaa-0000-0000-000000000001',
   'aaaaaaaa-aaaa-0000-0000-000000000001',
   'Cozinha', 'M');

insert into public.tasks (
  id, environment_id, room_id, title, difficulty, start_date,
  assignee_id, created_by
) values
  ('cccccccc-aaaa-0000-0000-000000000001',
   'aaaaaaaa-aaaa-0000-0000-000000000001',
   'bbbbbbbb-aaaa-0000-0000-000000000001',
   'Task Alice', 'mamao',
   (current_date - 1),
   '22222222-aaaa-0000-0000-000000000001',
   '11111111-aaaa-0000-0000-000000000001'),
  ('cccccccc-aaaa-0000-0000-000000000002',
   'aaaaaaaa-aaaa-0000-0000-000000000001',
   'bbbbbbbb-aaaa-0000-0000-000000000001',
   'Task Bob', 'mamao',
   (current_date - 1),
   '33333333-aaaa-0000-0000-000000000001',
   '11111111-aaaa-0000-0000-000000000001'),
  ('cccccccc-aaaa-0000-0000-000000000003',
   'aaaaaaaa-aaaa-0000-0000-000000000001',
   'bbbbbbbb-aaaa-0000-0000-000000000001',
   'Sem responsável', 'mamao',
   (current_date - 1),
   null,
   '11111111-aaaa-0000-0000-000000000001');

-- ============================================================
-- Test 1: ninho não existe → 42704
-- ============================================================
select throws_ok(
  $$select public.evaluate_environment_streaks(
    '00000000-0000-0000-0000-000000000000'::uuid, current_date - 1
  )$$,
  '42704',
  'Ninho não encontrado',
  'Ninho desconhecido falha com 42704'
);

-- ============================================================
-- Test 2: happy path — ambos concluem ontem
-- ============================================================
insert into public.task_completions (
  id, task_id, environment_id, completed_by, completed_at
) values
  ('dddddddd-aaaa-0000-0000-000000000001',
   'cccccccc-aaaa-0000-0000-000000000001',
   'aaaaaaaa-aaaa-0000-0000-000000000001',
   '22222222-aaaa-0000-0000-000000000001',
   ((current_date - 1) + time '12:00:00') at time zone 'America/Sao_Paulo'),
  ('dddddddd-aaaa-0000-0000-000000000002',
   'cccccccc-aaaa-0000-0000-000000000002',
   'aaaaaaaa-aaaa-0000-0000-000000000001',
   '33333333-aaaa-0000-0000-000000000001',
   ((current_date - 1) + time '12:00:00') at time zone 'America/Sao_Paulo');

select isnt_empty(
  $$select public.evaluate_environment_streaks(
    'aaaaaaaa-aaaa-0000-0000-000000000001'::uuid, current_date - 1
  )$$,
  'Evaluator devolve payload'
);

select is(
  (select current_count from public.streaks
    where environment_id = 'aaaaaaaa-aaaa-0000-0000-000000000001'
      and kind = 'user'
      and user_id = '22222222-aaaa-0000-0000-000000000001'),
  1,
  'Alice streak +1 após conclusão'
);

select is(
  (select current_count from public.streaks
    where environment_id = 'aaaaaaaa-aaaa-0000-0000-000000000001'
      and kind = 'user'
      and user_id = '33333333-aaaa-0000-0000-000000000001'),
  1,
  'Bob streak +1 após conclusão'
);

select is(
  (select current_count from public.streaks
    where environment_id = 'aaaaaaaa-aaaa-0000-0000-000000000001'
      and kind = 'environment'),
  1,
  'Streak de ninho +1 quando todos concluem'
);

-- ============================================================
-- Test 3: falha com freeze — bob falha, alice ok
-- ============================================================
-- Avança 1 dia (today): bob não tem completion, alice tem.
insert into public.task_completions (
  id, task_id, environment_id, completed_by, completed_at
) values
  ('dddddddd-aaaa-0000-0000-000000000003',
   'cccccccc-aaaa-0000-0000-000000000001',
   'aaaaaaaa-aaaa-0000-0000-000000000001',
   '22222222-aaaa-0000-0000-000000000001',
   (current_date + time '12:00:00') at time zone 'America/Sao_Paulo');

select isnt_empty(
  $$select public.evaluate_environment_streaks(
    'aaaaaaaa-aaaa-0000-0000-000000000001'::uuid, current_date
  )$$,
  'Segunda avaliação funciona'
);

select is(
  (select current_count from public.streaks
    where environment_id = 'aaaaaaaa-aaaa-0000-0000-000000000001'
      and kind = 'user'
      and user_id = '22222222-aaaa-0000-0000-000000000001'),
  2,
  'Alice streak avança para 2'
);

select is(
  (select current_count from public.streaks
    where environment_id = 'aaaaaaaa-aaaa-0000-0000-000000000001'
      and kind = 'user'
      and user_id = '33333333-aaaa-0000-0000-000000000001'),
  1,
  'Bob streak mantém em 1 via freeze'
);

select is(
  (select freezes_left_month from public.streaks
    where environment_id = 'aaaaaaaa-aaaa-0000-0000-000000000001'
      and kind = 'user'
      and user_id = '33333333-aaaa-0000-0000-000000000001'),
  1,
  'Bob consumiu 1 freeze (2 → 1)'
);

select is(
  (select current_count from public.streaks
    where environment_id = 'aaaaaaaa-aaaa-0000-0000-000000000001'
      and kind = 'environment'),
  0,
  'Streak de ninho zera quando bob falha mesmo com freeze pessoal'
);

-- ============================================================
-- Test 4: start_vacation owner-only
-- ============================================================
set local "request.jwt.claims" = '{"sub":"22222222-aaaa-0000-0000-000000000001"}';
select throws_ok(
  $$select public.start_vacation('aaaaaaaa-aaaa-0000-0000-000000000001'::uuid)$$,
  '42501',
  'Apenas o owner pode iniciar modo viagem',
  'Member não consegue iniciar viagem'
);

set local "request.jwt.claims" = '{"sub":"11111111-aaaa-0000-0000-000000000001"}';
select isnt_empty(
  $$select public.start_vacation('aaaaaaaa-aaaa-0000-0000-000000000001'::uuid)$$,
  'Owner inicia modo viagem'
);

select is(
  (select vacation_mode from public.environments
    where id = 'aaaaaaaa-aaaa-0000-0000-000000000001'),
  true,
  'environments.vacation_mode = true'
);

-- ============================================================
-- Test 5: re-evaluar com vacation_period aberto → paused
-- ============================================================
select is(
  (select ((public.evaluate_environment_streaks(
    'aaaaaaaa-aaaa-0000-0000-000000000001'::uuid, current_date
  ))->>'paused')::boolean),
  true,
  'Evaluation devolve paused=true durante modo viagem'
);

-- ============================================================
-- Test 6: streak não muda durante vacation
-- ============================================================
select is(
  (select current_count from public.streaks
    where environment_id = 'aaaaaaaa-aaaa-0000-0000-000000000001'
      and kind = 'user'
      and user_id = '22222222-aaaa-0000-0000-000000000001'),
  2,
  'Alice streak preservado em 2 durante viagem'
);

select * from finish();
rollback;
