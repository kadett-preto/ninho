-- Ninho — Fase 6.5: RPC `complete_task`.
-- IDEA.md §5.4 + §5.8 + §5.9 + §7.1.
--
-- Cobertura:
--   * Sem sessão → 28000.
--   * Task inexistente / outsider → 42704 sem revelar tenancy.
--   * Membro que não é responsável → 42501.
--   * Happy path: completion + dust + feed + audit + notif suprimida.
--   * Idempotência no mesmo dia evita poeira/feed duplicados.
--   * Owner pode concluir task atribuída a outro morador com foto válida.
--   * Photo path inválido é rejeitado.
--   * Task arquivada rejeita.

begin;
select plan(20);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner-complete@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'member-complete@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'other-complete@test.local'),
  ('44444444-4444-4444-4444-444444444444', 'outsider-complete@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-1000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'Ninho Complete',
   'America/Sao_Paulo');

set local role postgres;
insert into public.environment_members (environment_id, user_id, role)
values
  ('aaaaaaaa-1000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'member'),
  ('aaaaaaaa-1000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'member');

insert into public.rooms (id, environment_id, name, size_category) values
  ('bbbbbbbb-1000-0000-0000-000000000001', 'aaaaaaaa-1000-0000-0000-000000000001', 'Cozinha', 'M');

insert into public.tasks (
  id, environment_id, room_id, title, difficulty, start_date, assignee_id, created_by
) values
  ('cccccccc-1000-0000-0000-000000000001',
   'aaaaaaaa-1000-0000-0000-000000000001',
   'bbbbbbbb-1000-0000-0000-000000000001',
   'Lavar a louça',
   'mamao',
   current_date,
   '22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-1000-0000-0000-000000000002',
   'aaaaaaaa-1000-0000-0000-000000000001',
   'bbbbbbbb-1000-0000-0000-000000000001',
   'Varrer a sala',
   'embacada',
   current_date,
   '22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-1000-0000-0000-000000000003',
   'aaaaaaaa-1000-0000-0000-000000000001',
   'bbbbbbbb-1000-0000-0000-000000000001',
   'Task arquivada',
   'treta',
   current_date,
   '22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-1000-0000-0000-000000000004',
   'aaaaaaaa-1000-0000-0000-000000000001',
   'bbbbbbbb-1000-0000-0000-000000000001',
   'Task com foto inválida',
   'mamao',
   current_date,
   '22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111');

update public.tasks
   set archived_at = now()
 where id = 'cccccccc-1000-0000-0000-000000000003';

insert into public.notification_log (
  environment_id, user_id, task_id, channel, slot, scheduled_for
) values
  ('aaaaaaaa-1000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222',
   'cccccccc-1000-0000-0000-000000000001',
   'push', 'afternoon', now() + interval '1 hour'),
  ('aaaaaaaa-1000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222',
   'cccccccc-1000-0000-0000-000000000001',
   'push', 'morning', now() - interval '1 hour');

insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
values (
  'task-completion-photos',
  'aaaaaaaa-1000-0000-0000-000000000001/task-completions/cccccccc-1000-0000-0000-000000000002/owner.jpg',
  '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111',
  '{"mimetype":"image/jpeg","size":1000}'::jsonb
);

-- 1) Sem sessão → 28000.
set local role authenticated;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.complete_task('cccccccc-1000-0000-0000-000000000001'::uuid)$$,
  '28000',
  'Sem sessão Supabase ativa',
  'rejeita sem auth.uid()'
);

-- 2) Task inexistente → 42704.
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select throws_ok(
  $$select public.complete_task('cccccccc-9999-0000-0000-000000000001'::uuid)$$,
  '42704',
  'Task não encontrada',
  'rejeita task inexistente'
);

-- 3) Outsider recebe 42704 sem revelar existência.
set local "request.jwt.claims" = '{"sub":"44444444-4444-4444-4444-444444444444"}';
select throws_ok(
  $$select public.complete_task('cccccccc-1000-0000-0000-000000000001'::uuid)$$,
  '42704',
  'Task não encontrada',
  'outsider não enumera task'
);

-- 4) Membro não responsável não conclui task alheia.
set local "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333"}';
select throws_ok(
  $$select public.complete_task('cccccccc-1000-0000-0000-000000000001'::uuid)$$,
  '42501',
  'Apenas o responsável pode concluir esta task',
  'member não responsável rejeitado'
);

-- 5) Happy path assignee.
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select results_eq(
  $$select (public.complete_task('cccccccc-1000-0000-0000-000000000001'::uuid)->>'reward_delta')::int$$,
  array[5],
  'mamao credita 5 poeiras'
);

set local role postgres;
select results_eq(
  $$select count(*)::int from public.task_completions
      where task_id = 'cccccccc-1000-0000-0000-000000000001'
        and completed_by = '22222222-2222-2222-2222-222222222222'$$,
  array[1],
  'cria task_completion'
);

select results_eq(
  $$select coalesce(sum(delta), 0)::int from public.dust_ledger
      where related_task_id = 'cccccccc-1000-0000-0000-000000000001'$$,
  array[5],
  'cria dust_ledger com delta correto'
);

select results_eq(
  $$select count(*)::int from public.notification_log
      where task_id = 'cccccccc-1000-0000-0000-000000000001'
        and suppressed_reason = 'task_completed'$$,
  array[1],
  'suprime apenas notificação futura restante'
);

select results_eq(
  $$select count(*)::int from public.feed_events
      where event_type = 'task.completed'
        and payload->>'task_title' = 'Lavar a louça'$$,
  array[1],
  'emite feed event'
);

select results_eq(
  $$select count(*)::int from public.audit_log
      where action = 'task.complete'
        and target_id = 'cccccccc-1000-0000-0000-000000000001'$$,
  array[1],
  'grava audit_log'
);

-- 11) Idempotência: segunda chamada no mesmo dia não duplica crédito/feed.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select results_eq(
  $$select (public.complete_task('cccccccc-1000-0000-0000-000000000001'::uuid)->>'already_completed')::boolean$$,
  array[true],
  'segunda chamada retorna already_completed'
);

set local role postgres;
select results_eq(
  $$select count(*)::int from public.task_completions
      where task_id = 'cccccccc-1000-0000-0000-000000000001'$$,
  array[1],
  'não duplica completion'
);

select results_eq(
  $$select coalesce(sum(delta), 0)::int from public.dust_ledger
      where related_task_id = 'cccccccc-1000-0000-0000-000000000001'$$,
  array[5],
  'não duplica poeira'
);

select results_eq(
  $$select count(*)::int from public.feed_events
      where payload->>'task_id' = 'cccccccc-1000-0000-0000-000000000001'$$,
  array[1],
  'não duplica feed'
);

-- 15) Owner pode concluir task atribuída a outro morador com foto válida.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';
select results_eq(
  $$select (public.complete_task(
        'cccccccc-1000-0000-0000-000000000002'::uuid,
        'aaaaaaaa-1000-0000-0000-000000000001/task-completions/cccccccc-1000-0000-0000-000000000002/owner.jpg'
      )->>'reward_delta')::int$$,
  array[15],
  'owner pode concluir com foto e embacada credita 15'
);

set local role postgres;
select results_eq(
  $$select delta from public.dust_ledger
      where related_task_id = 'cccccccc-1000-0000-0000-000000000002'
        and user_id = '11111111-1111-1111-1111-111111111111'$$,
  array[15],
  'poeira vai para quem concluiu'
);

select results_eq(
  $$select photo_path from public.task_completions
      where task_id = 'cccccccc-1000-0000-0000-000000000002'$$,
  array['aaaaaaaa-1000-0000-0000-000000000001/task-completions/cccccccc-1000-0000-0000-000000000002/owner.jpg'],
  'grava photo_path validado'
);

select results_eq(
  $$select payload->>'photo_path' from public.feed_events
      where payload->>'task_id' = 'cccccccc-1000-0000-0000-000000000002'$$,
  array['aaaaaaaa-1000-0000-0000-000000000001/task-completions/cccccccc-1000-0000-0000-000000000002/owner.jpg'],
  'feed event inclui photo_path'
);

-- 19) Photo path inválido é rejeitado antes de inserir completion.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select throws_ok(
  $$select public.complete_task(
      'cccccccc-1000-0000-0000-000000000004'::uuid,
      'aaaaaaaa-1000-0000-0000-000000000001/task-completions/cccccccc-1000-0000-0000-000000000004/nao-existe.jpg'
    )$$,
  '22023',
  'Foto de conclusão inválida',
  'rejeita foto inexistente'
);

-- 20) Task arquivada rejeita.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select throws_ok(
  $$select public.complete_task('cccccccc-1000-0000-0000-000000000003'::uuid)$$,
  '22023',
  'Task arquivada',
  'não conclui task arquivada'
);

select * from finish();
rollback;
