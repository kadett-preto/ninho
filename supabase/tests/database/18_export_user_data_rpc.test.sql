-- Ninho - Fase 11.2 / LGPD: RPC export_user_data.
--
-- Cobertura:
--   * anon sem grant.
--   * authenticated tem grant; retorna JSON com chaves esperadas.
--   * Apenas dados do caller — outsider tem audit log vazio + sem
--     completions/dust de outro user.
--   * Rate-limit: 6a tentativa em 24h falha com 54000.
--   * Audit log gravado a cada chamada.

begin;
select plan(11);

insert into auth.users (id, email) values
  ('11111111-1111-aaaa-0000-000000000001', 'a-export@test.local'),
  ('22222222-2222-aaaa-0000-000000000001', 'b-export@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-aaaa-0000-000000000001"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-1111-aaaa-0000-000000000001',
   '11111111-1111-aaaa-0000-000000000001',
   'Ninho Export',
   'America/Sao_Paulo');

set local role postgres;
insert into public.environment_members (environment_id, user_id, role) values
  ('aaaaaaaa-1111-aaaa-0000-000000000001',
   '22222222-2222-aaaa-0000-000000000001',
   'member');

insert into public.dust_ledger (environment_id, user_id, delta, reason) values
  ('aaaaaaaa-1111-aaaa-0000-000000000001',
   '11111111-1111-aaaa-0000-000000000001',
   5,
   'task.completion'),
  ('aaaaaaaa-1111-aaaa-0000-000000000001',
   '22222222-2222-aaaa-0000-000000000001',
   15,
   'task.completion');

-- 1) anon sem grant.
set local role anon;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.export_user_data()$$,
  '42501',
  null,
  'anon sem grant em export_user_data'
);

-- 2) authenticated A exporta com sucesso — cacheamos em temp table
-- para evitar múltiplas chamadas (cada call grava audit + rate-limit).
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-aaaa-0000-000000000001"}';
create temp table _export_a on commit drop as
  select public.export_user_data() as data;

select isnt_empty(
  $$select data from _export_a$$,
  'authenticated A executa export_user_data'
);

-- 3) Payload contém chaves esperadas.
select ok(
  (select data ? 'user' from _export_a),
  'payload tem chave user'
);
select ok(
  (select data ? 'memberships' from _export_a),
  'payload tem chave memberships'
);
select ok(
  (select data ? 'dust_ledger' from _export_a),
  'payload tem chave dust_ledger'
);
select ok(
  (select data ? 'audit_log' from _export_a),
  'payload tem chave audit_log'
);

-- 4) dust_ledger só do caller — A tem 1 entry (5), não vê 15 de B.
select is(
  (select jsonb_array_length(data->'dust_ledger') from _export_a),
  1,
  'A vê apenas 1 entry de dust_ledger (própria)'
);

select is(
  (select (data->'dust_ledger'->0->>'delta')::int from _export_a),
  5,
  'A vê o próprio delta=5'
);

-- 5) audit_log gravado.
set local role postgres;
select ok(
  (select count(*)::int from public.audit_log
    where action = 'user.export'
      and actor_id = '11111111-1111-aaaa-0000-000000000001') >= 1,
  'audit_log user.export gravado'
);

-- 6) Outsider B vê dust_ledger só seu (15).
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-aaaa-0000-000000000001"}';
create temp table _export_b on commit drop as
  select public.export_user_data() as data;
select is(
  (select (data->'dust_ledger'->0->>'delta')::int from _export_b),
  15,
  'B vê o próprio delta=15'
);

-- 7) Rate-limit: preenche audit_log com 5 entries pra simular limite.
set local role postgres;
delete from public.audit_log where action = 'user.export';
insert into public.audit_log (actor_id, action, target_type, target_id)
select '11111111-1111-aaaa-0000-000000000001', 'user.export', 'user',
       '11111111-1111-aaaa-0000-000000000001'
  from generate_series(1, 5);

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-aaaa-0000-000000000001"}';
select throws_ok(
  $$select public.export_user_data()$$,
  '54000',
  'Limite de exportações por dia atingido',
  'rate-limit dispara após 5 exports em 24h'
);

select * from finish();
rollback;
