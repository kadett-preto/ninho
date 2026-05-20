-- Ninho — RLS testes de isolamento multi-tenant (IDEA.md §7.1, §8.3).
-- Verifica que Alice e Bob, donos de ninhos distintos, nunca enxergam ou
-- mutam dados do outro. Cobre helpers + environments + environment_members
-- + rooms + tasks.

begin;
select plan(26);

-- ---- Setup -----------------------------------------------------------------

-- Crio 3 usuários em auth.users; o trigger on_auth_user_created cria as linhas
-- correspondentes em public.users automaticamente. Atualizamos depois apenas o
-- display_name para nomes amigáveis no teste.
insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'alice@test.local'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bob@test.local'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'carol@test.local');

update public.users set display_name = 'Alice'
 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
update public.users set display_name = 'Bob'
 where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
update public.users set display_name = 'Carol'
 where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

-- Alice cria seu ninho. Inserção feita como postgres (bypass RLS) para
-- simular o caminho "trigger handle_new_environment cria membership owner".
insert into public.environments (id, owner_id, name, timezone) values
  ('eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Ninho Alice', 'America/Sao_Paulo');

-- Bob cria o dele.
insert into public.environments (id, owner_id, name, timezone) values
  ('eeeeeeee-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ninho Bob', 'America/Sao_Paulo');

-- Carol entra no ninho da Alice como member (simula aceite de convite).
insert into public.environment_members (environment_id, user_id, role) values
  ('eeeeeeee-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'member');

-- Rooms iniciais (criadas via postgres; clientes testam o acesso).
insert into public.rooms (id, environment_id, name, size_category) values
  ('11111111-aaaa-1111-1111-111111111111', 'eeeeeeee-1111-1111-1111-111111111111', 'Sala Alice', 'M'),
  ('22222222-bbbb-2222-2222-222222222222', 'eeeeeeee-2222-2222-2222-222222222222', 'Sala Bob', 'M');

-- Tasks iniciais.
insert into public.tasks (id, environment_id, room_id, title, difficulty, start_date, assignee_id, created_by) values
  ('aaaaaaaa-1111-1111-1111-111111111111',
   'eeeeeeee-1111-1111-1111-111111111111',
   '11111111-aaaa-1111-1111-111111111111',
   'Aspirar sala', 'embacada', current_date,
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-2222-2222-2222-222222222222',
   'eeeeeeee-2222-2222-2222-222222222222',
   '22222222-bbbb-2222-2222-222222222222',
   'Tirar lixo', 'mamao', current_date,
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

-- ---- Helpers ---------------------------------------------------------------

set local role authenticated;

-- ---- 1. is_environment_member ---------------------------------------------

set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select ok(public.is_environment_member('eeeeeeee-1111-1111-1111-111111111111'::uuid),
          'Alice é membro do próprio ninho');
select ok(not public.is_environment_member('eeeeeeee-2222-2222-2222-222222222222'::uuid),
          'Alice NÃO é membro do ninho do Bob');
select ok(public.is_environment_owner('eeeeeeee-1111-1111-1111-111111111111'::uuid),
          'Alice é owner do próprio ninho');
select ok(not public.is_environment_owner('eeeeeeee-2222-2222-2222-222222222222'::uuid),
          'Alice NÃO é owner do ninho do Bob');

set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc"}';
select ok(public.is_environment_member('eeeeeeee-1111-1111-1111-111111111111'::uuid),
          'Carol é member no ninho da Alice (via convite)');
select ok(not public.is_environment_owner('eeeeeeee-1111-1111-1111-111111111111'::uuid),
          'Carol NÃO é owner');

-- ---- 2. environments SELECT visibility -------------------------------------

set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select results_eq(
  'select count(*)::int from public.environments',
  array[1],
  'Alice vê 1 environment (o próprio)'
);

set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select results_eq(
  'select count(*)::int from public.environments',
  array[1],
  'Bob vê 1 environment (o próprio)'
);

set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc"}';
select results_eq(
  'select count(*)::int from public.environments',
  array[1],
  'Carol (member do ninho Alice) vê 1 environment'
);

-- ---- 3. environments UPDATE — só owner ------------------------------------

set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
update public.environments set name = 'Ninho Alice (renomeado)' where id = 'eeeeeeee-1111-1111-1111-111111111111';
select results_eq(
  $$select name from public.environments where id = 'eeeeeeee-1111-1111-1111-111111111111'$$,
  array['Ninho Alice (renomeado)'::text],
  'Alice consegue renomear o próprio ninho'
);

-- Carol é member, não owner — UPDATE não falha mas afeta 0 linhas.
set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc"}';
update public.environments set name = 'tentativa carol' where id = 'eeeeeeee-1111-1111-1111-111111111111';

-- Carol é member do ninho da Alice, então enxerga a linha — usa SELECT dela
-- para confirmar que o nome NÃO mudou.
select is(
  (select name from public.environments where id = 'eeeeeeee-1111-1111-1111-111111111111'),
  'Ninho Alice (renomeado)'::text,
  'Carol (member) NÃO consegue renomear ninho'
);

-- Bob tentando renomear ninho da Alice — UPDATE não casa policy, 0 linhas.
set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
update public.environments set name = 'invadido' where id = 'eeeeeeee-1111-1111-1111-111111111111';

-- Bob não enxerga o env da Alice; valida pela Alice.
set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select is(
  (select name from public.environments where id = 'eeeeeeee-1111-1111-1111-111111111111'),
  'Ninho Alice (renomeado)'::text,
  'Bob não conseguiu mutar ninho da Alice (RLS bloqueia)'
);

-- ---- 4. environment_members visibility ------------------------------------

set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select results_eq(
  $$select count(*)::int from public.environment_members where environment_id = 'eeeeeeee-1111-1111-1111-111111111111'$$,
  array[2],
  'Alice vê 2 membros (ela própria + Carol)'
);

set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select results_eq(
  $$select count(*)::int from public.environment_members where environment_id = 'eeeeeeee-1111-1111-1111-111111111111'$$,
  array[0],
  'Bob não enxerga membros do ninho da Alice'
);

-- ---- 5. rooms isolation ----------------------------------------------------

set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select results_eq(
  'select count(*)::int from public.rooms',
  array[1],
  'Alice vê só seus cômodos'
);

set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select results_eq(
  'select count(*)::int from public.rooms',
  array[1],
  'Bob vê só seus cômodos'
);

set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc"}';
select results_eq(
  'select count(*)::int from public.rooms',
  array[1],
  'Carol (member Alice) vê cômodo da Alice'
);

-- Bob não consegue inserir cômodo no ninho da Alice.
set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select throws_ok(
  $$insert into public.rooms (environment_id, name, size_category) values ('eeeeeeee-1111-1111-1111-111111111111', 'invasao', 'P')$$,
  '42501',
  'new row violates row-level security policy for table "rooms"',
  'Bob bloqueado de inserir cômodo no ninho Alice'
);

-- ---- 6. tasks isolation ----------------------------------------------------

set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select results_eq(
  'select count(*)::int from public.tasks',
  array[1],
  'Alice vê só tasks do seu ninho'
);

set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select results_eq(
  'select count(*)::int from public.tasks',
  array[1],
  'Bob vê só tasks do seu ninho'
);

-- Bob tenta inserir task no ninho da Alice — RLS bloqueia.
select throws_ok(
  $$insert into public.tasks (environment_id, title, difficulty, start_date, created_by) values ('eeeeeeee-1111-1111-1111-111111111111', 'invasao', 'mamao', current_date, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')$$,
  '42501',
  'new row violates row-level security policy for table "tasks"',
  'Bob bloqueado de inserir task no ninho Alice'
);

-- Carol (member do ninho Alice) consegue inserir task.
set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc"}';
insert into public.tasks (environment_id, title, difficulty, start_date, created_by)
  values ('eeeeeeee-1111-1111-1111-111111111111', 'Tarefa Carol', 'mamao', current_date, 'cccccccc-cccc-cccc-cccc-cccccccccccc');
select results_eq(
  'select count(*)::int from public.tasks',
  array[2],
  'Carol consegue inserir task como member do ninho Alice'
);

-- Carol tenta criar task com created_by mentindo (fingindo ser Alice).
select throws_ok(
  $$insert into public.tasks (environment_id, title, difficulty, start_date, created_by) values ('eeeeeeee-1111-1111-1111-111111111111', 'fake', 'mamao', current_date, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')$$,
  '42501',
  'new row violates row-level security policy for table "tasks"',
  'Member não consegue forjar created_by'
);

-- ---- 7. task_completions ---------------------------------------------------

-- Alice completa a própria task.
set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
insert into public.task_completions (task_id, environment_id, completed_by)
  values ('aaaaaaaa-1111-1111-1111-111111111111', 'eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

select results_eq(
  'select count(*)::int from public.task_completions',
  array[1],
  'Alice registra conclusão da própria task'
);

-- Bob tenta marcar como concluída a task da Alice.
set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select throws_ok(
  $$insert into public.task_completions (task_id, environment_id, completed_by) values ('aaaaaaaa-1111-1111-1111-111111111111', 'eeeeeeee-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')$$,
  '42501',
  'new row violates row-level security policy for table "task_completions"',
  'Bob bloqueado de completar task em ninho que não é dele'
);

-- Carol tenta forjar completed_by.
set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc"}';
select throws_ok(
  $$insert into public.task_completions (task_id, environment_id, completed_by) values ('aaaaaaaa-1111-1111-1111-111111111111', 'eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')$$,
  '42501',
  'new row violates row-level security policy for table "task_completions"',
  'Carol não pode forjar completed_by'
);

select * from finish();
rollback;
