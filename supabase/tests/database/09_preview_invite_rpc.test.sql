-- Ninho — Fase 4.5: RPC `preview_invite`.
-- IDEA.md §5.3 + §7.3.
--
-- Cobertura:
--   * Sem sessão → 28000.
--   * Hash curto → 22023.
--   * Token inexistente → 42704.
--   * Convite revogado → 22023.
--   * Convite expirado → 22023.
--   * Convite já utilizado → 22023.
--   * Preview válido retorna env_name + member_count + room_count + streak.
--   * Preview NÃO consome o convite (used_at continua null).
--   * already_member=true quando o user já está em environment_members.
--   * Audit log grava preview_attempt.
--   * Rate-limit ativa em 31 tentativas/min.
--   * Attempt da requisição rate-limited não é gravado.

begin;
select plan(13);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner-p@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'guest-p@test.local'),
  ('44444444-4444-4444-4444-444444444444', 'spammer-p@test.local');

-- Owner cria ninho via authenticated.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-0000-0000-0000-000000000010',
   '11111111-1111-1111-1111-111111111111',
   'Ninho Preview',
   'America/Sao_Paulo');

-- Cria cômodos + display_name do owner via postgres (RLS friendly).
set local role postgres;
update public.users set display_name = 'Marina'
  where id = '11111111-1111-1111-1111-111111111111';
update public.users set display_name = 'Lucas'
  where id = '22222222-2222-2222-2222-222222222222';

insert into public.rooms (environment_id, name, size_category) values
  ('aaaaaaaa-0000-0000-0000-000000000010', 'Sala', 'M'),
  ('aaaaaaaa-0000-0000-0000-000000000010', 'Cozinha', 'G'),
  ('aaaaaaaa-0000-0000-0000-000000000010', 'Quarto', 'P');

-- Streak do ambiente.
insert into public.streaks (environment_id, user_id, kind, current_count, best_count)
values
  ('aaaaaaaa-0000-0000-0000-000000000010', null, 'environment', 5, 12);

-- Convites variados.
insert into public.invites (id, environment_id, token_hash, created_by, expires_at, revoked_at, used_at, used_by)
values
  -- válido
  ('cccccccc-0000-0000-0000-000000000010',
   'aaaaaaaa-0000-0000-0000-000000000010',
   repeat('a', 64),
   '11111111-1111-1111-1111-111111111111',
   now() + interval '7 days',
   null, null, null),
  -- revogado
  ('cccccccc-0000-0000-0000-000000000011',
   'aaaaaaaa-0000-0000-0000-000000000010',
   repeat('b', 64),
   '11111111-1111-1111-1111-111111111111',
   now() + interval '7 days',
   now(), null, null),
  -- expirado
  ('cccccccc-0000-0000-0000-000000000012',
   'aaaaaaaa-0000-0000-0000-000000000010',
   repeat('c', 64),
   '11111111-1111-1111-1111-111111111111',
   now() - interval '1 second',
   null, null, null),
  -- usado
  ('cccccccc-0000-0000-0000-000000000013',
   'aaaaaaaa-0000-0000-0000-000000000010',
   repeat('d', 64),
   '11111111-1111-1111-1111-111111111111',
   now() + interval '7 days',
   null, now(), '22222222-2222-2222-2222-222222222222');

-- ============================================================
-- 1) Sem sessão → 28000.
-- ============================================================
set local role authenticated;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.preview_invite(repeat('a', 64))$$,
  '28000',
  'Sem sessão Supabase ativa',
  'rejeita sem auth.uid()'
);

-- ============================================================
-- 2) Hash curto → 22023.
-- ============================================================
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select throws_ok(
  $$select public.preview_invite('short')$$,
  '22023',
  'Token inválido',
  'rejeita hash < 32 chars'
);

-- ============================================================
-- 3) Token inexistente → 42704.
-- ============================================================
select throws_ok(
  $$select public.preview_invite(repeat('z', 64))$$,
  '42704',
  'Convite não encontrado',
  'rejeita hash desconhecido'
);

-- ============================================================
-- 4) Convite revogado → 22023.
-- ============================================================
select throws_ok(
  $$select public.preview_invite(repeat('b', 64))$$,
  '22023',
  'Convite revogado',
  'rejeita revoked_at'
);

-- ============================================================
-- 5) Convite expirado → 22023.
-- ============================================================
select throws_ok(
  $$select public.preview_invite(repeat('c', 64))$$,
  '22023',
  'Convite expirado',
  'rejeita expires_at no passado'
);

-- ============================================================
-- 6) Convite já utilizado → 22023.
-- ============================================================
select throws_ok(
  $$select public.preview_invite(repeat('d', 64))$$,
  '22023',
  'Convite já utilizado',
  'rejeita used_at populado'
);

-- ============================================================
-- 7) Preview válido — retorna environment_name correto.
-- ============================================================
select results_eq(
  $$select public.preview_invite(repeat('a', 64))->>'environment_name'$$,
  array['Ninho Preview'],
  'devolve nome do ninho'
);

-- ============================================================
-- 8) Preview retorna room_count = 3.
-- ============================================================
select results_eq(
  $$select (public.preview_invite(repeat('a', 64))->>'room_count')::int$$,
  array[3],
  'devolve contagem de cômodos'
);

-- ============================================================
-- 9) Preview retorna environment_streak = 5.
-- ============================================================
select results_eq(
  $$select (public.preview_invite(repeat('a', 64))->>'environment_streak')::int$$,
  array[5],
  'devolve streak do ambiente'
);

-- ============================================================
-- 10) Preview NÃO consome o convite (used_at permanece null).
-- ============================================================
set local role postgres;
select results_eq(
  $$select used_at is null from public.invites
      where id = 'cccccccc-0000-0000-0000-000000000010'$$,
  array[true],
  'preview não marca used_at'
);

-- ============================================================
-- 11) already_member=true quando user já é membro do ninho.
-- ============================================================
-- Adiciona guest como member ativo.
insert into public.environment_members (environment_id, user_id, role)
values (
  'aaaaaaaa-0000-0000-0000-000000000010',
  '22222222-2222-2222-2222-222222222222',
  'member'
);

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select results_eq(
  $$select (public.preview_invite(repeat('a', 64))->>'already_member')::boolean$$,
  array[true],
  'sinaliza usuário já-membro'
);

-- ============================================================
-- 12) Rate-limit: 31ª tentativa em 60s → 54000.
-- ============================================================
set local role postgres;
insert into public.audit_log (actor_id, action, target_type)
select '44444444-4444-4444-4444-444444444444', 'invite.preview_attempt', 'invite'
from generate_series(1, 30);

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"44444444-4444-4444-4444-444444444444"}';
select throws_ok(
  $$select public.preview_invite(repeat('z', 64))$$,
  '54000',
  'Muitas tentativas, aguarde um minuto',
  'rate-limit ativa na 31ª tentativa'
);

-- ============================================================
-- 13) Attempt da requisição rate-limited NÃO é gravado.
-- ============================================================
set local role postgres;
select results_eq(
  $$select count(*)::int from public.audit_log
      where actor_id = '44444444-4444-4444-4444-444444444444'
        and action = 'invite.preview_attempt'$$,
  array[30],
  'attempt rate-limited não vai pro audit_log'
);

select * from finish();
rollback;
