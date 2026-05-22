-- Ninho — Fase 8: push_tokens + notification_preferences.
--
-- Cobertura:
--   * register_push_token sem sessão → 28000.
--   * Token < 32 chars → 22023.
--   * Upsert idempotente: mesma chamada não duplica.
--   * Re-register em outro user reassigna (cenário re-login no device).
--   * revoke_push_token marca apenas o próprio.
--   * Trigger auto-cria notification_preferences ao criar user.
--   * notification_preferences: RLS bloqueia leitura cross-user.
--   * push_tokens: RLS bloqueia INSERT/UPDATE direto do client.

begin;
select plan(11);

-- Trigger em auth.users (handle_new_auth_user) cria public.users e em
-- public.users (users_after_insert_preferences) cria notification_preferences.
insert into auth.users (id, email) values
  ('aaaa1111-0000-0000-0000-000000000001', 'alice-push@test.local'),
  ('bbbb2222-0000-0000-0000-000000000001', 'bob-push@test.local');

-- Test 1: trigger criou preferences default
select is(
  (select count(*) from public.notification_preferences
    where user_id in (
      'aaaa1111-0000-0000-0000-000000000001',
      'bbbb2222-0000-0000-0000-000000000001'
    )),
  2::bigint,
  'Trigger auto-criou preferências para 2 usuários'
);

-- Test 2: sem sessão → 28000
set local role authenticated;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.register_push_token('a'::text, 'android'::public.push_platform, null)$$,
  '28000',
  'Sem sessão Supabase ativa',
  'Sem auth.uid() falha 28000'
);

-- Test 3: token curto → 22023
set local "request.jwt.claims" = '{"sub":"aaaa1111-0000-0000-0000-000000000001"}';
select throws_ok(
  $$select public.register_push_token('curto'::text, 'android'::public.push_platform, null)$$,
  '22023',
  'Token inválido',
  'Token < 32 chars rejeitado'
);

-- Test 4: register válido
select isnt_empty(
  $$select public.register_push_token(
    'token-android-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'::text,
    'android'::public.push_platform,
    'Galaxy S24'::text
  )$$,
  'Register válido retorna uuid'
);

-- Test 5: upsert idempotente — mesma chamada não duplica
select public.register_push_token(
  'token-android-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'::text,
  'android'::public.push_platform,
  'Galaxy S24'::text
);
set local role postgres;
select is(
  (select count(*) from public.push_tokens
    where token = 'token-android-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  1::bigint,
  'Upsert idempotente: mesma row'
);

-- Test 6: re-register em outro user reassigna
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"bbbb2222-0000-0000-0000-000000000001"}';
select public.register_push_token(
  'token-android-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'::text,
  'android'::public.push_platform,
  'Galaxy S24'::text
);
set local role postgres;
select is(
  (select user_id from public.push_tokens
    where token = 'token-android-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  'bbbb2222-0000-0000-0000-000000000001'::uuid,
  'Re-register reassigna token para novo user'
);

-- Test 7: revoke marca revoked_at
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"bbbb2222-0000-0000-0000-000000000001"}';
select public.revoke_push_token(
  'token-android-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'::text
);
set local role postgres;
select isnt(
  (select revoked_at from public.push_tokens
    where token = 'token-android-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
  null,
  'revoke setou revoked_at'
);

-- Test 8: revoke não toca em token de outro user
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"aaaa1111-0000-0000-0000-000000000001"}';
select public.register_push_token(
  'token-alice-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'::text,
  'android'::public.push_platform,
  null
);

set local "request.jwt.claims" = '{"sub":"bbbb2222-0000-0000-0000-000000000001"}';
select public.revoke_push_token(
  'token-alice-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'::text
);
set local role postgres;
select is(
  (select revoked_at from public.push_tokens
    where token = 'token-alice-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'),
  null,
  'revoke não afeta token de outro user'
);

-- Test 9: RLS bloqueia INSERT direto em push_tokens
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"aaaa1111-0000-0000-0000-000000000001"}';
select throws_ok(
  $$insert into public.push_tokens (user_id, token, platform)
    values ('aaaa1111-0000-0000-0000-000000000001', 'bypass-bypass-bypass-bypass-bypass-bypass', 'android')$$,
  '42501',
  null,
  'INSERT direto bloqueado pela RLS'
);

-- Test 10: RLS bloqueia leitura cross-user em notification_preferences
set local "request.jwt.claims" = '{"sub":"aaaa1111-0000-0000-0000-000000000001"}';
select is(
  (select count(*) from public.notification_preferences
    where user_id = 'bbbb2222-0000-0000-0000-000000000001'),
  0::bigint,
  'Alice não enxerga preferences da Bob'
);

-- Test 11: usuário consegue UPDATE das próprias preferences
update public.notification_preferences
   set push_enabled = false
 where user_id = 'aaaa1111-0000-0000-0000-000000000001';
set local role postgres;
select is(
  (select push_enabled from public.notification_preferences
    where user_id = 'aaaa1111-0000-0000-0000-000000000001'),
  false,
  'Alice toggla push_enabled na própria row'
);

select * from finish();
rollback;
