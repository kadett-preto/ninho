-- Ninho — Fase 9: RPCs transfer_task + get_dust_balance + set_transfer_item_enabled.
--
-- Cobertura:
--   * Sem sessão → 28000.
--   * Task inexistente → 42704.
--   * Não-membro → 42501.
--   * Não-responsável tenta transferir → 42501.
--   * Destinatário fora do ninho → 42501.
--   * Destinatário = caller → 22023.
--   * Saldo insuficiente → 22023.
--   * Item desativado pelo owner → 22023.
--   * Limite semanal (2ª tentativa na mesma semana) → 22023.
--   * Happy path: dust_ledger -30, task reassigned, transfer registrado,
--     audit_log gravado.
--   * Owner toggle item via set_transfer_item_enabled.
--   * get_dust_balance reflete saldo atual.

begin;
select plan(16);

insert into auth.users (id, email) values
  ('11111111-cccc-0000-0000-000000000001', 'owner-shop@test.local'),
  ('22222222-cccc-0000-0000-000000000001', 'alice-shop@test.local'),
  ('33333333-cccc-0000-0000-000000000001', 'bob-shop@test.local'),
  ('44444444-cccc-0000-0000-000000000001', 'outsider-shop@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-cccc-0000-0000-000000000001"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-cccc-0000-0000-000000000001',
   '11111111-cccc-0000-0000-000000000001',
   'Ninho Shop',
   'America/Sao_Paulo');

set local role postgres;
insert into public.environment_members (environment_id, user_id, role) values
  ('aaaaaaaa-cccc-0000-0000-000000000001', '22222222-cccc-0000-0000-000000000001', 'member'),
  ('aaaaaaaa-cccc-0000-0000-000000000001', '33333333-cccc-0000-0000-000000000001', 'member');

insert into public.rooms (id, environment_id, name, size_category) values
  ('bbbbbbbb-cccc-0000-0000-000000000001',
   'aaaaaaaa-cccc-0000-0000-000000000001',
   'Cozinha', 'M');

insert into public.tasks (
  id, environment_id, room_id, title, difficulty, start_date,
  assignee_id, created_by
) values
  ('cccccccc-cccc-0000-0000-000000000001',
   'aaaaaaaa-cccc-0000-0000-000000000001',
   'bbbbbbbb-cccc-0000-0000-000000000001',
   'Task Alice', 'treta',
   current_date,
   '22222222-cccc-0000-0000-000000000001',
   '11111111-cccc-0000-0000-000000000001');

-- ============================================================
-- Test 1: anon role nem chega ao corpo da função (sem grant)
-- ============================================================
set local role anon;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.transfer_task(
    'cccccccc-cccc-0000-0000-000000000001'::uuid,
    '33333333-cccc-0000-0000-000000000001'::uuid
  )$$,
  '42501',
  null,
  'Anon sem grant falha 42501 antes de executar corpo'
);

-- ============================================================
-- Test 2: task inexistente
-- ============================================================
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-cccc-0000-0000-000000000001"}';
select throws_ok(
  $$select public.transfer_task(
    '00000000-0000-0000-0000-000000000000'::uuid,
    '33333333-cccc-0000-0000-000000000001'::uuid
  )$$,
  '42704',
  'Tarefa não encontrada',
  'Task inexistente falha 42704'
);

-- ============================================================
-- Test 3: outsider não consegue (not member)
-- ============================================================
set local "request.jwt.claims" = '{"sub":"44444444-cccc-0000-0000-000000000001"}';
select throws_ok(
  $$select public.transfer_task(
    'cccccccc-cccc-0000-0000-000000000001'::uuid,
    '33333333-cccc-0000-0000-000000000001'::uuid
  )$$,
  '42501',
  null,
  'Outsider falha 42501'
);

-- ============================================================
-- Test 4: bob (não responsável) tenta transferir alice's task
-- ============================================================
set local "request.jwt.claims" = '{"sub":"33333333-cccc-0000-0000-000000000001"}';
select throws_ok(
  $$select public.transfer_task(
    'cccccccc-cccc-0000-0000-000000000001'::uuid,
    '22222222-cccc-0000-0000-000000000001'::uuid
  )$$,
  '42501',
  'Você só transfere as próprias tarefas',
  'Não-responsável falha 42501'
);

-- ============================================================
-- Test 5: destinatário fora do ninho
-- ============================================================
set local "request.jwt.claims" = '{"sub":"22222222-cccc-0000-0000-000000000001"}';
select throws_ok(
  $$select public.transfer_task(
    'cccccccc-cccc-0000-0000-000000000001'::uuid,
    '44444444-cccc-0000-0000-000000000001'::uuid
  )$$,
  '42501',
  'Destinatário não está neste ninho',
  'Destinatário fora do ninho falha 42501'
);

-- ============================================================
-- Test 6: destinatário = caller
-- ============================================================
select throws_ok(
  $$select public.transfer_task(
    'cccccccc-cccc-0000-0000-000000000001'::uuid,
    '22222222-cccc-0000-0000-000000000001'::uuid
  )$$,
  '22023',
  'Destinatário inválido (não pode ser você mesmo)',
  'Self-transfer falha 22023'
);

-- ============================================================
-- Test 7: saldo insuficiente (alice tem 0 poeiras)
-- ============================================================
select throws_ok(
  format(
    'select public.transfer_task(%L::uuid, %L::uuid)',
    'cccccccc-cccc-0000-0000-000000000001',
    '33333333-cccc-0000-0000-000000000001'
  ),
  '22023',
  null,
  'Saldo insuficiente falha 22023'
);

-- ============================================================
-- Credita 50 poeiras pra alice (concluiu uma "treta") e re-testa
-- ============================================================
set local role postgres;
insert into public.dust_ledger (environment_id, user_id, delta, reason) values
  ('aaaaaaaa-cccc-0000-0000-000000000001',
   '22222222-cccc-0000-0000-000000000001',
   50, 'task_completion');

-- get_dust_balance
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-cccc-0000-0000-000000000001"}';
select is(
  public.get_dust_balance('aaaaaaaa-cccc-0000-0000-000000000001'::uuid),
  50,
  'get_dust_balance retorna 50 após crédito'
);

-- ============================================================
-- Test 8: item desativado pelo owner
-- ============================================================
set local "request.jwt.claims" = '{"sub":"11111111-cccc-0000-0000-000000000001"}';
select public.set_transfer_item_enabled(
  'aaaaaaaa-cccc-0000-0000-000000000001'::uuid, false
);
set local "request.jwt.claims" = '{"sub":"22222222-cccc-0000-0000-000000000001"}';
select throws_ok(
  $$select public.transfer_task(
    'cccccccc-cccc-0000-0000-000000000001'::uuid,
    '33333333-cccc-0000-0000-000000000001'::uuid
  )$$,
  '22023',
  'Transferência desativada neste ninho',
  'Item desativado bloqueia transferência'
);

-- Membro tenta toggle (não-owner) → 42501
set local "request.jwt.claims" = '{"sub":"22222222-cccc-0000-0000-000000000001"}';
select throws_ok(
  $$select public.set_transfer_item_enabled(
    'aaaaaaaa-cccc-0000-0000-000000000001'::uuid, true
  )$$,
  '42501',
  'Apenas o owner pode mudar a loja',
  'Member não toggla item'
);

-- Owner reabilita
set local "request.jwt.claims" = '{"sub":"11111111-cccc-0000-0000-000000000001"}';
select public.set_transfer_item_enabled(
  'aaaaaaaa-cccc-0000-0000-000000000001'::uuid, true
);

-- ============================================================
-- Test 9 + 10: happy path
-- ============================================================
set local "request.jwt.claims" = '{"sub":"22222222-cccc-0000-0000-000000000001"}';
select isnt_empty(
  $$select public.transfer_task(
    'cccccccc-cccc-0000-0000-000000000001'::uuid,
    '33333333-cccc-0000-0000-000000000001'::uuid
  )$$,
  'Transfer happy path retorna payload'
);

set local role postgres;
select is(
  (select assignee_id from public.tasks
    where id = 'cccccccc-cccc-0000-0000-000000000001'),
  '33333333-cccc-0000-0000-000000000001'::uuid,
  'Task reassignada para o destinatário'
);

select is(
  (select count(*)::int from public.task_transfers
    where task_id = 'cccccccc-cccc-0000-0000-000000000001'),
  1,
  'task_transfers tem 1 linha'
);

select is(
  (select coalesce(sum(delta), 0)::int from public.dust_ledger
    where user_id = '22222222-cccc-0000-0000-000000000001'
      and environment_id = 'aaaaaaaa-cccc-0000-0000-000000000001'),
  20,
  'Saldo de alice agora 50 - 30 = 20'
);

select is(
  (select count(*)::int from public.audit_log
    where environment_id = 'aaaaaaaa-cccc-0000-0000-000000000001'
      and actor_id = '22222222-cccc-0000-0000-000000000001'
      and action = 'shop.task_transfer'
      and target_id = 'cccccccc-cccc-0000-0000-000000000001'),
  1,
  'audit_log registra transferência'
);

-- ============================================================
-- Test 11: 2ª tentativa na mesma semana
-- ============================================================
-- Cria 2ª task atribuída a alice
set local role postgres;
insert into public.tasks (
  id, environment_id, room_id, title, difficulty, start_date,
  assignee_id, created_by
) values
  ('cccccccc-cccc-0000-0000-000000000002',
   'aaaaaaaa-cccc-0000-0000-000000000001',
   'bbbbbbbb-cccc-0000-0000-000000000001',
   'Task Alice 2', 'mamao',
   current_date,
   '22222222-cccc-0000-0000-000000000001',
   '11111111-cccc-0000-0000-000000000001');
insert into public.dust_ledger (environment_id, user_id, delta, reason) values
  ('aaaaaaaa-cccc-0000-0000-000000000001',
   '22222222-cccc-0000-0000-000000000001',
   100, 'task_completion');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-cccc-0000-0000-000000000001"}';
select throws_ok(
  $$select public.transfer_task(
    'cccccccc-cccc-0000-0000-000000000002'::uuid,
    '33333333-cccc-0000-0000-000000000001'::uuid
  )$$,
  '22023',
  'Você já usou sua transferência desta semana',
  '2ª transferência na mesma semana ISO bloqueada'
);

select * from finish();
rollback;
