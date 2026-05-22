-- Ninho - Fase 10.3/10.4: moderacao e denuncia do mural.
--
-- Cobertura:
--   * Anon sem grant nos RPCs.
--   * Outsider nao denuncia item de outro ninho.
--   * Membro denuncia item visivel, sem duplicar sinal por usuario.
--   * Denuncia grava audit_log.
--   * Autor remove propria foto via soft hide.
--   * Membro comum nao modera item alheio.
--   * Owner oculta qualquer item.
--   * Owner deleta qualquer item.
--   * Item oculto sai da leitura de membro comum, mas owner ainda enxerga.

begin;
select plan(15);

insert into auth.users (id, email) values
  ('11111111-dddd-0000-0000-000000000001', 'owner-feed@test.local'),
  ('22222222-dddd-0000-0000-000000000001', 'author-feed@test.local'),
  ('33333333-dddd-0000-0000-000000000001', 'member-feed@test.local'),
  ('44444444-dddd-0000-0000-000000000001', 'outsider-feed@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-dddd-0000-0000-000000000001"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-dddd-0000-0000-000000000001',
   '11111111-dddd-0000-0000-000000000001',
   'Ninho Feed',
   'America/Sao_Paulo');

set local role postgres;
insert into public.environment_members (environment_id, user_id, role) values
  ('aaaaaaaa-dddd-0000-0000-000000000001', '22222222-dddd-0000-0000-000000000001', 'member'),
  ('aaaaaaaa-dddd-0000-0000-000000000001', '33333333-dddd-0000-0000-000000000001', 'member');

insert into public.feed_events (
  id, environment_id, actor_id, event_type, payload, created_at
) values
  ('eeeeeeee-dddd-0000-0000-000000000001',
   'aaaaaaaa-dddd-0000-0000-000000000001',
   '22222222-dddd-0000-0000-000000000001',
   'task.completed',
   '{"photo_path":"aaaaaaaa-dddd-0000-0000-000000000001/task-completions/task/photo.jpg","task_title":"Cozinha"}'::jsonb,
   now()),
  ('eeeeeeee-dddd-0000-0000-000000000002',
   'aaaaaaaa-dddd-0000-0000-000000000001',
   '33333333-dddd-0000-0000-000000000001',
   'weekly.summary',
   '{"summary":"Semana boa"}'::jsonb,
   now()),
  ('eeeeeeee-dddd-0000-0000-000000000003',
   'aaaaaaaa-dddd-0000-0000-000000000001',
   '33333333-dddd-0000-0000-000000000001',
   'member.joined',
   '{"member_name":"Joao"}'::jsonb,
   now());

-- 1) Anon nao executa RPC.
set local role anon;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.report_feed_event('eeeeeeee-dddd-0000-0000-000000000001'::uuid)$$,
  '42501',
  null,
  'anon sem grant para report_feed_event'
);

-- 2) Outsider nao denuncia.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"44444444-dddd-0000-0000-000000000001"}';
select throws_ok(
  $$select public.report_feed_event('eeeeeeee-dddd-0000-0000-000000000001'::uuid)$$,
  '42501',
  'Você não participa deste ninho',
  'outsider nao denuncia item do ninho'
);

-- 3) Membro denuncia item visivel.
set local "request.jwt.claims" = '{"sub":"33333333-dddd-0000-0000-000000000001"}';
select isnt_empty(
  $$select public.report_feed_event('eeeeeeee-dddd-0000-0000-000000000001'::uuid, 'spam')$$,
  'membro denuncia item'
);

set local role postgres;
select is(
  (select count(*)::int from public.feed_event_reports
    where feed_event_id = 'eeeeeeee-dddd-0000-0000-000000000001'
      and reporter_id = '33333333-dddd-0000-0000-000000000001'),
  1,
  'denuncia persistida'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'feed.report'
      and target_id = 'eeeeeeee-dddd-0000-0000-000000000001'),
  1,
  'denuncia grava audit_log'
);

-- 6) Mesmo membro atualiza o sinal sem duplicar linha.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"33333333-dddd-0000-0000-000000000001"}';
select isnt_empty(
  $$select public.report_feed_event('eeeeeeee-dddd-0000-0000-000000000001'::uuid, 'abuse', 'detalhe')$$,
  'segunda denuncia do mesmo usuario retorna ok'
);

set local role postgres;
select is(
  (select count(*)::int from public.feed_event_reports
    where feed_event_id = 'eeeeeeee-dddd-0000-0000-000000000001'
      and reporter_id = '33333333-dddd-0000-0000-000000000001'),
  1,
  'denuncia nao duplica por usuario'
);

-- 8) Autor remove a propria foto do mural.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-dddd-0000-0000-000000000001"}';
select isnt_empty(
  $$select public.moderate_feed_event('eeeeeeee-dddd-0000-0000-000000000001'::uuid, 'delete_photo')$$,
  'autor remove propria foto'
);

set local role postgres;
select ok(
  (select hidden_at is not null
     from public.feed_events
    where id = 'eeeeeeee-dddd-0000-0000-000000000001'),
  'remove foto faz soft hide do feed_event'
);

select is(
  (select count(*)::int from public.audit_log
    where action = 'feed.photo.delete'
      and target_id = 'eeeeeeee-dddd-0000-0000-000000000001'),
  1,
  'remove foto grava audit_log'
);

-- 11-12) Item oculto some para membro comum, mas owner ainda enxerga.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"33333333-dddd-0000-0000-000000000001"}';
select is(
  (select count(*)::int from public.feed_events
    where id = 'eeeeeeee-dddd-0000-0000-000000000001'),
  0,
  'membro comum nao ve item oculto'
);

set local "request.jwt.claims" = '{"sub":"11111111-dddd-0000-0000-000000000001"}';
select is(
  (select count(*)::int from public.feed_events
    where id = 'eeeeeeee-dddd-0000-0000-000000000001'),
  1,
  'owner ve item oculto para moderacao'
);

-- 13) Membro comum nao modera item alheio.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"33333333-dddd-0000-0000-000000000001"}';
select throws_ok(
  $$select public.moderate_feed_event('eeeeeeee-dddd-0000-0000-000000000002'::uuid, 'hide')$$,
  '42501',
  'Apenas o owner pode moderar o mural',
  'membro comum nao oculta item'
);

-- 14) Owner oculta qualquer item.
set local "request.jwt.claims" = '{"sub":"11111111-dddd-0000-0000-000000000001"}';
select isnt_empty(
  $$select public.moderate_feed_event('eeeeeeee-dddd-0000-0000-000000000002'::uuid, 'hide')$$,
  'owner oculta item'
);

-- 15) Owner deleta qualquer item.
select isnt_empty(
  $$select public.moderate_feed_event('eeeeeeee-dddd-0000-0000-000000000003'::uuid, 'delete')$$,
  'owner deleta item'
);

select * from finish();
rollback;
