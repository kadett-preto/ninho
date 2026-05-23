-- Ninho - Fase 11.3 + 11.4 / LGPD: RPC request_account_deletion.
--
-- Cobertura:
--   * anon sem grant.
--   * Soft-delete simples: users.deleted_at preenchido + left_at em
--     environment_members do caller.
--   * Owner com outro membro ativo: auto-promove o mais antigo.
--   * Owner sem outros membros: arquiva o environment.
--   * Idempotência: 2a chamada retorna already_deleted=true sem efeito.
--   * Audit log gravado.

begin;
select plan(14);

insert into auth.users (id, email) values
  ('11111111-aaaa-bbbb-0000-000000000001', 'owner-del@test.local'),
  ('22222222-aaaa-bbbb-0000-000000000001', 'member-del@test.local'),
  ('33333333-aaaa-bbbb-0000-000000000001', 'solo-del@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-aaaa-bbbb-0000-000000000001"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-aaaa-bbbb-0000-000000000001',
   '11111111-aaaa-bbbb-0000-000000000001',
   'Ninho Owner+Member',
   'America/Sao_Paulo');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"33333333-aaaa-bbbb-0000-000000000001"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-aaaa-bbbb-0000-000000000002',
   '33333333-aaaa-bbbb-0000-000000000001',
   'Ninho Solo',
   'America/Sao_Paulo');

set local role postgres;
-- Membro de Ninho Owner+Member (joined depois do owner).
insert into public.environment_members (environment_id, user_id, role, joined_at)
values (
  'aaaaaaaa-aaaa-bbbb-0000-000000000001',
  '22222222-aaaa-bbbb-0000-000000000001',
  'member',
  now() + interval '1 day'
);

-- 1) anon sem grant.
set local role anon;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.request_account_deletion()$$,
  '42501',
  null,
  'anon sem grant em request_account_deletion'
);

-- 2) Owner com outro membro: auto-promove + soft delete.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-aaaa-bbbb-0000-000000000001"}';
select isnt_empty(
  $$select public.request_account_deletion()$$,
  'owner com outro membro executa request_account_deletion'
);

set local role postgres;
select ok(
  (select deleted_at is not null from public.users
    where id = '11111111-aaaa-bbbb-0000-000000000001'),
  'users.deleted_at preenchido para owner-del'
);

select is(
  (select role::text from public.environment_members
    where environment_id = 'aaaaaaaa-aaaa-bbbb-0000-000000000001'
      and user_id = '22222222-aaaa-bbbb-0000-000000000001'),
  'owner',
  'membro 22222222 promovido a owner'
);

select is(
  (select owner_id from public.environments
    where id = 'aaaaaaaa-aaaa-bbbb-0000-000000000001'),
  '22222222-aaaa-bbbb-0000-000000000001'::uuid,
  'environments.owner_id atualizado'
);

select ok(
  (select left_at is not null from public.environment_members
    where environment_id = 'aaaaaaaa-aaaa-bbbb-0000-000000000001'
      and user_id = '11111111-aaaa-bbbb-0000-000000000001'),
  'caller saiu do ninho (left_at)'
);

select ok(
  (select archived_at is null from public.environments
    where id = 'aaaaaaaa-aaaa-bbbb-0000-000000000001'),
  'environment não arquivado (tinha outro membro)'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'environment.owner_auto_promoted'
      and target_id = '22222222-aaaa-bbbb-0000-000000000001'),
  1,
  'audit owner_auto_promoted gravado'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'user.deletion_request'
      and actor_id = '11111111-aaaa-bbbb-0000-000000000001'),
  1,
  'audit user.deletion_request gravado'
);

-- 3) Owner sem outros membros: arquiva environment.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"33333333-aaaa-bbbb-0000-000000000001"}';
select isnt_empty(
  $$select public.request_account_deletion()$$,
  'solo owner executa request_account_deletion'
);

set local role postgres;
select ok(
  (select archived_at is not null from public.environments
    where id = 'aaaaaaaa-aaaa-bbbb-0000-000000000002'),
  'environment solo arquivado'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'environment.archived'
      and target_id = 'aaaaaaaa-aaaa-bbbb-0000-000000000002'),
  1,
  'audit environment.archived gravado'
);

-- 4) Idempotência: 2a call retorna already_deleted=true.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-aaaa-bbbb-0000-000000000001"}';
select is(
  (select (public.request_account_deletion() ->> 'already_deleted')::boolean),
  true,
  '2a chamada retorna already_deleted=true'
);

-- 5) Idempotência não duplica audit.
set local role postgres;
select is(
  (select count(*)::int from public.audit_log
    where action = 'user.deletion_request'
      and actor_id = '11111111-aaaa-bbbb-0000-000000000001'),
  1,
  '2a chamada não duplica audit'
);

select * from finish();
rollback;
