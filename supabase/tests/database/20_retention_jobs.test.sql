-- Ninho - Fase 11.3 + 11.5 / LGPD: retention jobs.
--
-- Cobertura:
--   * anon sem grant em purge/archive.
--   * purge_deleted_accounts anonimiza só linhas com deleted_at > 30d.
--   * purge respeita p_retention_days e é idempotente (purged_at).
--   * archive_inactive_environments arquiva env sem membros há 30d.
--   * archive_inactive_environments ignora env com membro ativo.
--   * archive_inactive_environments ignora env sem membros mas recente.

begin;
select plan(13);

insert into auth.users (id, email) values
  ('aaaa1111-bbbb-cccc-dddd-eeeeeeee0001', 'old@del.test'),
  ('aaaa1111-bbbb-cccc-dddd-eeeeeeee0002', 'recent@del.test'),
  ('aaaa1111-bbbb-cccc-dddd-eeeeeeee0003', 'active@ok.test');

-- Trigger on_auth_user_created já criou linhas em public.users; só
-- ajustamos os campos relevantes (display_name + deleted_at).
update public.users
   set display_name = 'Marina Antiga',
       deleted_at = now() - interval '45 days'
 where id = 'aaaa1111-bbbb-cccc-dddd-eeeeeeee0001';

update public.users
   set display_name = 'Marina Recente',
       deleted_at = now() - interval '5 days'
 where id = 'aaaa1111-bbbb-cccc-dddd-eeeeeeee0002';

update public.users
   set display_name = 'Marina Ativa'
 where id = 'aaaa1111-bbbb-cccc-dddd-eeeeeeee0003';

-- 1) anon sem grant em purge.
set local role anon;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.purge_deleted_accounts(30)$$,
  '42501',
  null,
  'anon sem grant em purge_deleted_accounts'
);
select throws_ok(
  $$select public.archive_inactive_environments(30)$$,
  '42501',
  null,
  'anon sem grant em archive_inactive_environments'
);

-- 2) authenticated também não tem grant.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"aaaa1111-bbbb-cccc-dddd-eeeeeeee0003"}';
select throws_ok(
  $$select public.purge_deleted_accounts(30)$$,
  '42501',
  null,
  'authenticated sem grant em purge_deleted_accounts'
);

-- 3) postgres (service_role equivalente em testes) roda e retorna 1.
set local role postgres;
select is(
  (select public.purge_deleted_accounts(30)),
  1,
  'purge anonimiza 1 linha (45d)'
);

select is(
  (select display_name from public.users
    where id = 'aaaa1111-bbbb-cccc-dddd-eeeeeeee0001'),
  null,
  'display_name zerado pós-purge'
);

select ok(
  (select purged_at is not null from public.users
    where id = 'aaaa1111-bbbb-cccc-dddd-eeeeeeee0001'),
  'purged_at preenchido'
);

select is(
  (select display_name from public.users
    where id = 'aaaa1111-bbbb-cccc-dddd-eeeeeeee0002'),
  'Marina Recente',
  'usuário recente não foi tocado'
);

-- 4) Audit gravado.
select is(
  (select count(*)::int from public.audit_log
    where action = 'user.purged'
      and target_id = 'aaaa1111-bbbb-cccc-dddd-eeeeeeee0001'),
  1,
  'audit user.purged gravado'
);

-- 5) Idempotência: segunda chamada não re-purga.
select is(
  (select public.purge_deleted_accounts(30)),
  0,
  'segunda chamada de purge retorna 0 (idempotente)'
);

-- 6) Setup environments para archive.
insert into public.environments (id, owner_id, name, timezone, created_at)
values
  (
    'eeee0001-bbbb-cccc-dddd-eeeeeeee0001',
    'aaaa1111-bbbb-cccc-dddd-eeeeeeee0003',
    'Ninho Abandonado',
    'America/Sao_Paulo',
    now() - interval '120 days'
  ),
  (
    'eeee0001-bbbb-cccc-dddd-eeeeeeee0002',
    'aaaa1111-bbbb-cccc-dddd-eeeeeeee0003',
    'Ninho Ativo',
    'America/Sao_Paulo',
    now() - interval '60 days'
  ),
  (
    'eeee0001-bbbb-cccc-dddd-eeeeeeee0003',
    'aaaa1111-bbbb-cccc-dddd-eeeeeeee0003',
    'Ninho Recém Sem Membros',
    'America/Sao_Paulo',
    now() - interval '5 days'
  );

-- Trigger environments_after_insert criou a membership do owner pra cada
-- env. Ajustamos pra simular cenários:
--   * Abandonado: owner saiu há 45d.
update public.environment_members
   set joined_at = now() - interval '100 days',
       left_at = now() - interval '45 days'
 where environment_id = 'eeee0001-bbbb-cccc-dddd-eeeeeeee0001';

--   * Ativo: nada a fazer (ainda dentro).

--   * Recém sem membros: remove a membership do owner (env fica órfão com
--     created_at recente; archive não deve tocar — < 30d).
delete from public.environment_members
 where environment_id = 'eeee0001-bbbb-cccc-dddd-eeeeeeee0003';

-- 7) Archive deve pegar só o abandonado.
select is(
  (select public.archive_inactive_environments(30)),
  1,
  'archive marca 1 ninho (sem membros há 45d)'
);

select ok(
  (select archived_at is not null from public.environments
    where id = 'eeee0001-bbbb-cccc-dddd-eeeeeeee0001'),
  'ninho abandonado arquivado'
);

select ok(
  (select archived_at is null from public.environments
    where id = 'eeee0001-bbbb-cccc-dddd-eeeeeeee0002'),
  'ninho ativo intacto'
);

select ok(
  (select archived_at is null from public.environments
    where id = 'eeee0001-bbbb-cccc-dddd-eeeeeeee0003'),
  'ninho recém sem membros intacto (5d < 30d)'
);

select * from finish();
rollback;
