-- Ninho — Fase 11.9: audit coverage. Garante que mutações sensíveis
-- geram entrada em audit_log: start/end vacation, toggle loja, e
-- triggers em rooms/tasks.

begin;
select plan(11);

insert into auth.users (id, email) values
  ('cccc4444-1111-2222-3333-444444444401', 'audit-owner@test.local'),
  ('cccc4444-1111-2222-3333-444444444402', 'audit-member@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"cccc4444-1111-2222-3333-444444444401"}';
insert into public.environments (id, owner_id, name, timezone) values
  ('dddd5555-1111-2222-3333-444444444401',
   'cccc4444-1111-2222-3333-444444444401',
   'Audit Env',
   'America/Sao_Paulo');

-- 1) start_vacation gera audit.
select lives_ok(
  $$select public.start_vacation('dddd5555-1111-2222-3333-444444444401')$$,
  'start_vacation roda'
);
set local role postgres;
select is(
  (select count(*)::int from public.audit_log
    where action = 'environment.vacation_started'
      and environment_id = 'dddd5555-1111-2222-3333-444444444401'),
  1,
  'audit vacation_started gravado'
);

-- 2) end_vacation gera audit.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"cccc4444-1111-2222-3333-444444444401"}';
select lives_ok(
  $$select public.end_vacation('dddd5555-1111-2222-3333-444444444401')$$,
  'end_vacation roda'
);
set local role postgres;
select is(
  (select count(*)::int from public.audit_log
    where action = 'environment.vacation_ended'
      and environment_id = 'dddd5555-1111-2222-3333-444444444401'),
  1,
  'audit vacation_ended gravado'
);

-- 3) set_transfer_item_enabled gera audit.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"cccc4444-1111-2222-3333-444444444401"}';
select lives_ok(
  $$select public.set_transfer_item_enabled('dddd5555-1111-2222-3333-444444444401', false)$$,
  'set_transfer_item_enabled roda'
);
set local role postgres;
select is(
  (select count(*)::int from public.audit_log
    where action = 'shop.transfer_item_toggled'
      and (metadata ->> 'enabled')::boolean is false),
  1,
  'audit shop.transfer_item_toggled gravado'
);

-- 4) Trigger rooms insert/update/delete.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"cccc4444-1111-2222-3333-444444444401"}';
insert into public.rooms (id, environment_id, name, size_category) values
  ('eeee6666-1111-2222-3333-444444444401',
   'dddd5555-1111-2222-3333-444444444401',
   'Cozinha Audit',
   'M');

update public.rooms
   set name = 'Cozinha 2'
 where id = 'eeee6666-1111-2222-3333-444444444401';

delete from public.rooms
 where id = 'eeee6666-1111-2222-3333-444444444401';

set local role postgres;
select is(
  (select count(*)::int from public.audit_log
    where action = 'room.created'
      and target_id = 'eeee6666-1111-2222-3333-444444444401'),
  1,
  'audit room.created gravado'
);
select is(
  (select count(*)::int from public.audit_log
    where action = 'room.updated'
      and target_id = 'eeee6666-1111-2222-3333-444444444401'),
  1,
  'audit room.updated gravado'
);
select is(
  (select count(*)::int from public.audit_log
    where action = 'room.deleted'
      and target_id = 'eeee6666-1111-2222-3333-444444444401'),
  1,
  'audit room.deleted gravado'
);

-- 5) Trigger tasks insert/update (archive).
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"cccc4444-1111-2222-3333-444444444401"}';
insert into public.tasks (
  id, environment_id, title, difficulty, start_date, created_by
) values (
  'ffff7777-1111-2222-3333-444444444401',
  'dddd5555-1111-2222-3333-444444444401',
  'Limpar pia',
  'mamao',
  current_date,
  'cccc4444-1111-2222-3333-444444444401'
);

update public.tasks
   set archived_at = now()
 where id = 'ffff7777-1111-2222-3333-444444444401';

set local role postgres;
select is(
  (select count(*)::int from public.audit_log
    where action = 'task.created'
      and target_id = 'ffff7777-1111-2222-3333-444444444401'),
  1,
  'audit task.created gravado'
);
select is(
  (select count(*)::int from public.audit_log
    where action = 'task.archived'
      and target_id = 'ffff7777-1111-2222-3333-444444444401'),
  1,
  'audit task.archived gravado'
);

select * from finish();
rollback;
