-- Ninho - Fase 10.5: RPC publish_weekly_summary.
--
-- Cobertura:
--   * authenticated/anon sem grant.
--   * service_role insere weekly.summary + audit_log.
--   * Validacao: summary vazio, summary >600 chars, env inexistente.
--   * Payload preserva contadores e janela de tempo.
--   * RLS: membro le evento; outsider nao le.

begin;
select plan(12);

insert into auth.users (id, email) values
  ('11111111-eeee-0000-0000-000000000001', 'owner-w@test.local'),
  ('22222222-eeee-0000-0000-000000000001', 'member-w@test.local'),
  ('33333333-eeee-0000-0000-000000000001', 'outsider-w@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-eeee-0000-0000-000000000001"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-eeee-0000-0000-000000000001',
   '11111111-eeee-0000-0000-000000000001',
   'Ninho Resumo',
   'America/Sao_Paulo');

set local role postgres;
insert into public.environment_members (environment_id, user_id, role) values
  ('aaaaaaaa-eeee-0000-0000-000000000001',
   '22222222-eeee-0000-0000-000000000001',
   'member');

-- 1) anon não executa.
set local role anon;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.publish_weekly_summary(
      'aaaaaaaa-eeee-0000-0000-000000000001'::uuid,
      'oi',
      0, 0,
      current_date,
      current_date
    )$$,
  '42501',
  null,
  'anon sem grant em publish_weekly_summary'
);

-- 2) authenticated (membro) também não executa.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-eeee-0000-0000-000000000001"}';
select throws_ok(
  $$select public.publish_weekly_summary(
      'aaaaaaaa-eeee-0000-0000-000000000001'::uuid,
      'oi',
      0, 0,
      current_date,
      current_date
    )$$,
  '42501',
  null,
  'membro sem grant em publish_weekly_summary'
);

-- 3) service_role insere com sucesso.
set local role service_role;
select isnt_empty(
  $$select public.publish_weekly_summary(
      'aaaaaaaa-eeee-0000-0000-000000000001'::uuid,
      'Semana de cuidado no ninho.',
      3, 2,
      (current_date - 6),
      current_date,
      'claude-haiku-4-5'
    )$$,
  'service_role publica resumo semanal'
);

set local role postgres;
select is(
  (select count(*)::int from public.feed_events
    where environment_id = 'aaaaaaaa-eeee-0000-0000-000000000001'
      and event_type = 'weekly.summary'),
  1,
  'feed_event weekly.summary inserido'
);

select ok(
  (select payload->>'summary' = 'Semana de cuidado no ninho.'
     from public.feed_events
    where environment_id = 'aaaaaaaa-eeee-0000-0000-000000000001'
      and event_type = 'weekly.summary'
    limit 1),
  'payload preserva summary'
);

select is(
  (select (payload->>'task_count')::int from public.feed_events
    where event_type = 'weekly.summary'
      and environment_id = 'aaaaaaaa-eeee-0000-0000-000000000001'
    limit 1),
  3,
  'payload preserva task_count'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'feed.weekly_summary'
      and environment_id = 'aaaaaaaa-eeee-0000-0000-000000000001'),
  1,
  'audit_log gravado'
);

-- 4) summary vazio rejeitado.
set local role service_role;
select throws_ok(
  $$select public.publish_weekly_summary(
      'aaaaaaaa-eeee-0000-0000-000000000001'::uuid,
      '   ',
      0, 0,
      current_date,
      current_date
    )$$,
  '22023',
  'summary vazio',
  'rejeita summary vazio'
);

-- 5) summary longo demais rejeitado.
select throws_ok(
  format(
    $$select public.publish_weekly_summary(
        'aaaaaaaa-eeee-0000-0000-000000000001'::uuid,
        %L,
        0, 0,
        current_date,
        current_date
      )$$,
    repeat('x', 700)
  ),
  '22023',
  'summary muito longo',
  'rejeita summary > 600 chars'
);

-- 6) env inexistente rejeitado.
select throws_ok(
  $$select public.publish_weekly_summary(
      'bbbbbbbb-eeee-0000-0000-000000000099'::uuid,
      'qualquer coisa',
      0, 0,
      current_date,
      current_date
    )$$,
  '42704',
  'Ninho inexistente',
  'rejeita env inexistente'
);

-- 7) Membro enxerga o evento via RLS; outsider não.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-eeee-0000-0000-000000000001"}';
select is(
  (select count(*)::int from public.feed_events
    where environment_id = 'aaaaaaaa-eeee-0000-0000-000000000001'
      and event_type = 'weekly.summary'),
  1,
  'membro le weekly.summary do proprio ninho'
);

set local "request.jwt.claims" = '{"sub":"33333333-eeee-0000-0000-000000000001"}';
select is(
  (select count(*)::int from public.feed_events
    where environment_id = 'aaaaaaaa-eeee-0000-0000-000000000001'
      and event_type = 'weekly.summary'),
  0,
  'outsider nao le weekly.summary'
);

select * from finish();
rollback;
