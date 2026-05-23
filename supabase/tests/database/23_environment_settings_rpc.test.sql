-- Ninho — Fase 11.8: RPCs update_environment_name + remove_member.

begin;
select plan(14);

insert into auth.users (id, email) values
  ('aaaa2222-1111-2222-3333-444444444401', 'owner@cfg.test'),
  ('aaaa2222-1111-2222-3333-444444444402', 'member@cfg.test'),
  ('aaaa2222-1111-2222-3333-444444444403', 'outsider@cfg.test'),
  ('aaaa2222-1111-2222-3333-444444444404', 'second-owner@cfg.test');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"aaaa2222-1111-2222-3333-444444444401"}';
insert into public.environments (id, owner_id, name, timezone) values
  ('bbbb3333-1111-2222-3333-444444444401',
   'aaaa2222-1111-2222-3333-444444444401',
   'Nome Original',
   'America/Sao_Paulo');

set local role postgres;
insert into public.environment_members (environment_id, user_id, role, joined_at)
values (
  'bbbb3333-1111-2222-3333-444444444401',
  'aaaa2222-1111-2222-3333-444444444402',
  'member',
  now() + interval '1 day'
);
-- Co-owner pra testar bloqueio de remover owner.
insert into public.environment_members (environment_id, user_id, role, joined_at)
values (
  'bbbb3333-1111-2222-3333-444444444401',
  'aaaa2222-1111-2222-3333-444444444404',
  'owner',
  now() + interval '2 day'
);

-- 1) anon sem grant.
set local role anon;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.update_environment_name('bbbb3333-1111-2222-3333-444444444401', 'X')$$,
  '42501', null,
  'anon sem grant em update_environment_name'
);
select throws_ok(
  $$select public.remove_member('bbbb3333-1111-2222-3333-444444444401', 'aaaa2222-1111-2222-3333-444444444402')$$,
  '42501', null,
  'anon sem grant em remove_member'
);

-- 2) Member regular tenta renomear.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"aaaa2222-1111-2222-3333-444444444402"}';
select throws_ok(
  $$select public.update_environment_name('bbbb3333-1111-2222-3333-444444444401', 'Hack')$$,
  '42501', null,
  'member regular não pode renomear'
);

-- 3) Member regular tenta remover outro.
select throws_ok(
  $$select public.remove_member('bbbb3333-1111-2222-3333-444444444401', 'aaaa2222-1111-2222-3333-444444444404')$$,
  '42501', null,
  'member regular não pode remover'
);

-- 4) Owner renomeia com sucesso.
set local "request.jwt.claims" = '{"sub":"aaaa2222-1111-2222-3333-444444444401"}';
select lives_ok(
  $$select public.update_environment_name('bbbb3333-1111-2222-3333-444444444401', '  Novo Nome  ')$$,
  'owner renomeia'
);

set local role postgres;
select is(
  (select name from public.environments
    where id = 'bbbb3333-1111-2222-3333-444444444401'),
  'Novo Nome',
  'nome atualizado + trim aplicado'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'environment.renamed'
      and target_id = 'bbbb3333-1111-2222-3333-444444444401'),
  1,
  'audit environment.renamed gravado'
);

-- 5) Nome vazio rejeitado.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"aaaa2222-1111-2222-3333-444444444401"}';
select throws_ok(
  $$select public.update_environment_name('bbbb3333-1111-2222-3333-444444444401', '   ')$$,
  '22023', null,
  'nome vazio rejeitado'
);

-- 6) Owner tenta remover a si mesmo.
select throws_ok(
  $$select public.remove_member('bbbb3333-1111-2222-3333-444444444401', 'aaaa2222-1111-2222-3333-444444444401')$$,
  '22023', null,
  'auto-remoção rejeitada'
);

-- 7) Owner tenta remover outro owner.
select throws_ok(
  $$select public.remove_member('bbbb3333-1111-2222-3333-444444444401', 'aaaa2222-1111-2222-3333-444444444404')$$,
  '22023', null,
  'não pode remover outro owner'
);

-- 8) Outsider/inexistente.
select throws_ok(
  $$select public.remove_member('bbbb3333-1111-2222-3333-444444444401', 'aaaa2222-1111-2222-3333-444444444403')$$,
  '22023', null,
  'membro inexistente rejeitado'
);

-- 9) Happy path: remove member.
select lives_ok(
  $$select public.remove_member('bbbb3333-1111-2222-3333-444444444401', 'aaaa2222-1111-2222-3333-444444444402')$$,
  'owner remove member'
);

set local role postgres;
select ok(
  (select left_at is not null from public.environment_members
    where environment_id = 'bbbb3333-1111-2222-3333-444444444401'
      and user_id = 'aaaa2222-1111-2222-3333-444444444402'),
  'member.left_at preenchido'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'environment.member_removed'
      and target_id = 'aaaa2222-1111-2222-3333-444444444402'),
  1,
  'audit member_removed gravado'
);

select * from finish();
rollback;
