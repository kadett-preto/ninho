-- Ninho — Fase 11.7: RPC leave_environment.
--
-- Cobertura:
--   * anon sem grant.
--   * não-membro: 42501.
--   * id null: 22023.
--   * owner único com outro membro ativo: 22023.
--   * member regular: left_at preenchido + audit.
--   * owner sem outros membros: env arquivado + audit.
--   * idempotência: 2a chamada retorna already_left=true.

begin;
select plan(11);

insert into auth.users (id, email) values
  ('77777777-1111-2222-3333-444444444401', 'owner@leave.test'),
  ('77777777-1111-2222-3333-444444444402', 'member@leave.test'),
  ('77777777-1111-2222-3333-444444444403', 'outsider@leave.test'),
  ('77777777-1111-2222-3333-444444444404', 'solo@leave.test');

-- Owner + member env.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"77777777-1111-2222-3333-444444444401"}';
insert into public.environments (id, owner_id, name, timezone) values
  ('eeee9999-1111-2222-3333-444444444401',
   '77777777-1111-2222-3333-444444444401',
   'Ninho com membro',
   'America/Sao_Paulo');

set local role postgres;
insert into public.environment_members (environment_id, user_id, role, joined_at)
values (
  'eeee9999-1111-2222-3333-444444444401',
  '77777777-1111-2222-3333-444444444402',
  'member',
  now()
);

-- Solo env.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"77777777-1111-2222-3333-444444444404"}';
insert into public.environments (id, owner_id, name, timezone) values
  ('eeee9999-1111-2222-3333-444444444402',
   '77777777-1111-2222-3333-444444444404',
   'Ninho solo',
   'America/Sao_Paulo');

set local role postgres;

-- 1) anon sem grant.
set local role anon;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.leave_environment('eeee9999-1111-2222-3333-444444444401')$$,
  '42501',
  null,
  'anon sem grant em leave_environment'
);

-- 2) Não-membro.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"77777777-1111-2222-3333-444444444403"}';
select throws_ok(
  $$select public.leave_environment('eeee9999-1111-2222-3333-444444444401')$$,
  '42501',
  null,
  'outsider rejeitado'
);

-- 3) Null id.
set local "request.jwt.claims" = '{"sub":"77777777-1111-2222-3333-444444444402"}';
select throws_ok(
  $$select public.leave_environment(null)$$,
  '22023',
  null,
  'id null rejeitado'
);

-- 4) Owner único com outro membro: 22023.
set local "request.jwt.claims" = '{"sub":"77777777-1111-2222-3333-444444444401"}';
select throws_ok(
  $$select public.leave_environment('eeee9999-1111-2222-3333-444444444401')$$,
  '22023',
  null,
  'owner com membros precisa transferir'
);

-- 5) Member sai: left_at preenchido + audit.
set local "request.jwt.claims" = '{"sub":"77777777-1111-2222-3333-444444444402"}';
select isnt_empty(
  $$select public.leave_environment('eeee9999-1111-2222-3333-444444444401')$$,
  'member regular sai sem erro'
);

set local role postgres;
select ok(
  (select left_at is not null from public.environment_members
    where environment_id = 'eeee9999-1111-2222-3333-444444444401'
      and user_id = '77777777-1111-2222-3333-444444444402'),
  'member left_at preenchido'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'environment.member_left'
      and target_id = '77777777-1111-2222-3333-444444444402'),
  1,
  'audit member_left gravado'
);

-- 6) Solo owner sai: env arquivado.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"77777777-1111-2222-3333-444444444404"}';
select is(
  (select (public.leave_environment('eeee9999-1111-2222-3333-444444444402') ->> 'env_archived')::boolean),
  true,
  'solo owner -> env arquivado'
);

set local role postgres;
select ok(
  (select archived_at is not null from public.environments
    where id = 'eeee9999-1111-2222-3333-444444444402'),
  'environment solo arquivado'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'environment.archived'
      and target_id = 'eeee9999-1111-2222-3333-444444444402'),
  1,
  'audit environment.archived gravado para owner solo'
);

-- 7) Idempotência: 2a chamada do member.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"77777777-1111-2222-3333-444444444402"}';
select is(
  (select (public.leave_environment('eeee9999-1111-2222-3333-444444444401') ->> 'already_left')::boolean),
  true,
  '2a chamada do member retorna already_left=true'
);

select * from finish();
rollback;
