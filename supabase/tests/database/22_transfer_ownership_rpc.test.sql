-- Ninho — Fase 11.6: RPCs list_environment_members + transfer_ownership.
--
-- Cobertura:
--   * anon sem grant em ambos.
--   * outsider não enxerga lista de membros.
--   * member regular tenta transferir → 42501.
--   * owner tenta transferir pra si mesmo → 22023.
--   * owner tenta transferir pra outsider/saiu → 22023.
--   * owner transfere com sucesso: papéis trocados + owner_id atualizado.
--   * audit gravado.
--   * after-state: ex-owner não pode mais transferir.

begin;
select plan(14);

insert into auth.users (id, email) values
  ('99999999-1111-2222-3333-444444444401', 'owner@tx.test'),
  ('99999999-1111-2222-3333-444444444402', 'memberA@tx.test'),
  ('99999999-1111-2222-3333-444444444403', 'memberB@tx.test'),
  ('99999999-1111-2222-3333-444444444404', 'outsider@tx.test');

update public.users set display_name = 'Owner Inicial'
 where id = '99999999-1111-2222-3333-444444444401';
update public.users set display_name = 'Ana'
 where id = '99999999-1111-2222-3333-444444444402';
update public.users set display_name = 'João'
 where id = '99999999-1111-2222-3333-444444444403';

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"99999999-1111-2222-3333-444444444401"}';
insert into public.environments (id, owner_id, name, timezone) values
  ('ffff0000-1111-2222-3333-444444444401',
   '99999999-1111-2222-3333-444444444401',
   'Ninho TX',
   'America/Sao_Paulo');

set local role postgres;
insert into public.environment_members (environment_id, user_id, role, joined_at) values
  ('ffff0000-1111-2222-3333-444444444401',
   '99999999-1111-2222-3333-444444444402',
   'member',
   now() + interval '1 day'),
  ('ffff0000-1111-2222-3333-444444444401',
   '99999999-1111-2222-3333-444444444403',
   'member',
   now() + interval '2 day');

-- 1) anon sem grant.
set local role anon;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select * from public.list_environment_members('ffff0000-1111-2222-3333-444444444401')$$,
  '42501',
  null,
  'anon sem grant em list_environment_members'
);
select throws_ok(
  $$select public.transfer_ownership('ffff0000-1111-2222-3333-444444444401', '99999999-1111-2222-3333-444444444402')$$,
  '42501',
  null,
  'anon sem grant em transfer_ownership'
);

-- 2) Outsider vê lista vazia (RPC checa membership do caller).
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"99999999-1111-2222-3333-444444444404"}';
select is(
  (select count(*)::int from public.list_environment_members('ffff0000-1111-2222-3333-444444444401')),
  0,
  'outsider recebe lista vazia'
);

-- 3) Owner vê 3 membros.
set local "request.jwt.claims" = '{"sub":"99999999-1111-2222-3333-444444444401"}';
select is(
  (select count(*)::int from public.list_environment_members('ffff0000-1111-2222-3333-444444444401')),
  3,
  'owner vê 3 membros ativos'
);

-- 4) Member regular tenta transferir.
set local "request.jwt.claims" = '{"sub":"99999999-1111-2222-3333-444444444402"}';
select throws_ok(
  $$select public.transfer_ownership('ffff0000-1111-2222-3333-444444444401', '99999999-1111-2222-3333-444444444403')$$,
  '42501',
  null,
  'member regular não pode transferir'
);

-- 5) Owner tenta pra si mesmo.
set local "request.jwt.claims" = '{"sub":"99999999-1111-2222-3333-444444444401"}';
select throws_ok(
  $$select public.transfer_ownership('ffff0000-1111-2222-3333-444444444401', '99999999-1111-2222-3333-444444444401')$$,
  '22023',
  null,
  'owner -> caller rejeitado'
);

-- 6) Owner tenta pra outsider.
select throws_ok(
  $$select public.transfer_ownership('ffff0000-1111-2222-3333-444444444401', '99999999-1111-2222-3333-444444444404')$$,
  '22023',
  null,
  'transferir pra outsider rejeitado'
);

-- 7) Happy path: transfere pra Ana.
select isnt_empty(
  $$select public.transfer_ownership('ffff0000-1111-2222-3333-444444444401', '99999999-1111-2222-3333-444444444402')$$,
  'owner transfere com sucesso'
);

set local role postgres;
select is(
  (select role::text from public.environment_members
    where environment_id = 'ffff0000-1111-2222-3333-444444444401'
      and user_id = '99999999-1111-2222-3333-444444444402'),
  'owner',
  'Ana agora é owner'
);
select is(
  (select role::text from public.environment_members
    where environment_id = 'ffff0000-1111-2222-3333-444444444401'
      and user_id = '99999999-1111-2222-3333-444444444401'),
  'member',
  'Ex-owner agora é member'
);
select is(
  (select owner_id from public.environments
    where id = 'ffff0000-1111-2222-3333-444444444401'),
  '99999999-1111-2222-3333-444444444402'::uuid,
  'environments.owner_id atualizado'
);
select is(
  (select count(*)::int from public.audit_log
    where action = 'environment.ownership_transferred'
      and environment_id = 'ffff0000-1111-2222-3333-444444444401'),
  1,
  'audit ownership_transferred gravado'
);

-- 8) After-state: ex-owner não consegue transferir de novo.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"99999999-1111-2222-3333-444444444401"}';
select throws_ok(
  $$select public.transfer_ownership('ffff0000-1111-2222-3333-444444444401', '99999999-1111-2222-3333-444444444403')$$,
  '42501',
  null,
  'ex-owner não pode mais transferir'
);

-- 9) Novo owner consegue transferir pra outro membro.
set local "request.jwt.claims" = '{"sub":"99999999-1111-2222-3333-444444444402"}';
select isnt_empty(
  $$select public.transfer_ownership('ffff0000-1111-2222-3333-444444444401', '99999999-1111-2222-3333-444444444403')$$,
  'novo owner consegue transferir adiante'
);

select * from finish();
rollback;
