-- Ninho — Fase 4.3 + 4.8: RPC `accept_invite`.
-- IDEA.md §5.3 + §7.3.
--
-- Cobertura:
--   * Sem sessão → 28000.
--   * Token muito curto → 22023.
--   * Token inexistente → 42704.
--   * Convite válido aceito → membership inserida, used_at populado,
--     audit_log gravado (accept_attempt + accept).
--   * Reuso do mesmo token (one-time use) → 22023.
--   * Convite revogado → 22023.
--   * Convite expirado → 22023.
--   * Usuário já é membro: marca usado, retorna already_member=true.
--   * Rate limit: 11ª tentativa em 60s → 54000.

begin;
select plan(17);

-- Helper p/ gravar hash determinístico (em produção é sha256 do token claro;
-- aqui usamos strings >=32 chars que servem só como chave de lookup).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'guest@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'guest2@test.local'),
  ('44444444-4444-4444-4444-444444444444', 'spammer@test.local');

-- Owner cria ninho via authenticated (trigger registra membership owner).
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';

insert into public.environments (id, owner_id, name, timezone) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Ninho A', 'America/Sao_Paulo');

-- Cria 4 convites via postgres (bypassa RLS de invites): válido, revogado,
-- expirado, já usado por terceiro.
set local role postgres;
insert into public.invites (id, environment_id, token_hash, created_by, expires_at, revoked_at, used_at, used_by)
values
  ('cccccccc-0000-0000-0000-000000000001',
   'aaaaaaaa-0000-0000-0000-000000000001',
   repeat('a', 64),
   '11111111-1111-1111-1111-111111111111',
   now() + interval '7 days',
   null, null, null),
  ('cccccccc-0000-0000-0000-000000000002',
   'aaaaaaaa-0000-0000-0000-000000000001',
   repeat('b', 64),
   '11111111-1111-1111-1111-111111111111',
   now() + interval '7 days',
   now(), null, null),
  ('cccccccc-0000-0000-0000-000000000003',
   'aaaaaaaa-0000-0000-0000-000000000001',
   repeat('c', 64),
   '11111111-1111-1111-1111-111111111111',
   now() - interval '1 second',
   null, null, null),
  ('cccccccc-0000-0000-0000-000000000004',
   'aaaaaaaa-0000-0000-0000-000000000001',
   repeat('d', 64),
   '11111111-1111-1111-1111-111111111111',
   now() + interval '7 days',
   null, now(), '33333333-3333-3333-3333-333333333333');

-- ============================================================
-- 1) Sem sessão → 28000.
-- ============================================================
set local role authenticated;
set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.accept_invite(repeat('a', 64))$$,
  '28000',
  'Sem sessão Supabase ativa',
  'rejeita sem auth.uid()'
);

-- ============================================================
-- 2) Hash curto → 22023.
-- ============================================================
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select throws_ok(
  $$select public.accept_invite('short')$$,
  '22023',
  'Token inválido',
  'rejeita hash < 32 chars'
);

-- ============================================================
-- 3) Token inexistente → 42704.
-- ============================================================
select throws_ok(
  $$select public.accept_invite(repeat('z', 64))$$,
  '42704',
  'Convite não encontrado',
  'rejeita hash desconhecido'
);

-- ============================================================
-- 4) Convite revogado → 22023.
-- ============================================================
select throws_ok(
  $$select public.accept_invite(repeat('b', 64))$$,
  '22023',
  'Convite revogado',
  'rejeita revoked_at'
);

-- ============================================================
-- 5) Convite expirado → 22023.
-- ============================================================
select throws_ok(
  $$select public.accept_invite(repeat('c', 64))$$,
  '22023',
  'Convite expirado',
  'rejeita expires_at no passado'
);

-- ============================================================
-- 6) Convite já usado → 22023.
-- ============================================================
select throws_ok(
  $$select public.accept_invite(repeat('d', 64))$$,
  '22023',
  'Convite já utilizado',
  'rejeita used_at populado'
);

-- ============================================================
-- 7) Convite válido aceito → retorna ambient + already_member=false.
-- ============================================================
select results_eq(
  $$select (public.accept_invite(repeat('a', 64))->>'already_member')::boolean$$,
  array[false],
  'aceita convite válido (já não era membro)'
);

-- ============================================================
-- 8) Membership foi inserida.
-- ============================================================
set local role postgres;
select results_eq(
  $$select count(*)::int from public.environment_members
      where environment_id = 'aaaaaaaa-0000-0000-0000-000000000001'
        and user_id = '22222222-2222-2222-2222-222222222222'
        and role = 'member'
        and left_at is null$$,
  array[1],
  'environment_members ganhou linha para guest'
);

-- ============================================================
-- 9) Convite ficou marcado como usado pelo guest.
-- ============================================================
select results_eq(
  $$select used_by from public.invites
      where id = 'cccccccc-0000-0000-0000-000000000001'$$,
  array['22222222-2222-2222-2222-222222222222'::uuid],
  'used_by aponta para o guest'
);

select results_eq(
  $$select (used_at is not null)::boolean from public.invites
      where id = 'cccccccc-0000-0000-0000-000000000001'$$,
  array[true],
  'used_at foi populado'
);

-- ============================================================
-- 10) audit_log gravou attempt + accept.
-- ============================================================
select results_eq(
  $$select count(*)::int from public.audit_log
      where actor_id = '22222222-2222-2222-2222-222222222222'
        and action = 'invite.accept'
        and target_id = 'cccccccc-0000-0000-0000-000000000001'$$,
  array[1],
  'audit_log tem invite.accept'
);

select cmp_ok(
  (select count(*)::int from public.audit_log
     where actor_id = '22222222-2222-2222-2222-222222222222'
       and action = 'invite.accept_attempt'),
  '>=',
  1,
  'audit_log tem ao menos um invite.accept_attempt'
);

-- ============================================================
-- 11) One-time use: re-aceitar o mesmo token → 22023 (já usado).
-- ============================================================
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333"}';
select throws_ok(
  $$select public.accept_invite(repeat('a', 64))$$,
  '22023',
  'Convite já utilizado',
  'segundo aceite do mesmo token é rejeitado'
);

-- ============================================================
-- 12) Idempotência: usuário já-membro recebe novo convite válido,
-- aceita, retorna already_member=true e não cria membership duplicada.
-- ============================================================
set local role postgres;
insert into public.invites (id, environment_id, token_hash, created_by, expires_at)
values
  ('cccccccc-0000-0000-0000-000000000005',
   'aaaaaaaa-0000-0000-0000-000000000001',
   repeat('e', 64),
   '11111111-1111-1111-1111-111111111111',
   now() + interval '7 days');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select results_eq(
  $$select (public.accept_invite(repeat('e', 64))->>'already_member')::boolean$$,
  array[true],
  'já-membro aceita sem duplicar membership'
);

set local role postgres;
select results_eq(
  $$select count(*)::int from public.environment_members
      where environment_id = 'aaaaaaaa-0000-0000-0000-000000000001'
        and user_id = '22222222-2222-2222-2222-222222222222'
        and left_at is null$$,
  array[1],
  'environment_members continua única'
);

-- ============================================================
-- 13) Rate limit: 11ª tentativa em 60s → 54000.
-- ============================================================
-- Pré-popula 10 attempts no audit_log para o spammer.
insert into public.audit_log (actor_id, action, target_type)
select '44444444-4444-4444-4444-444444444444', 'invite.accept_attempt', 'invite'
from generate_series(1, 10);

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"44444444-4444-4444-4444-444444444444"}';
select throws_ok(
  $$select public.accept_invite(repeat('z', 64))$$,
  '54000',
  'Muitas tentativas, aguarde um minuto',
  'rate limit ativa na 11ª tentativa'
);

-- ============================================================
-- 14) Confere que o attempt do rate limit acima NÃO foi gravado
-- (rate-limit precede insert do attempt).
-- ============================================================
set local role postgres;
select results_eq(
  $$select count(*)::int from public.audit_log
      where actor_id = '44444444-4444-4444-4444-444444444444'
        and action = 'invite.accept_attempt'$$,
  array[10],
  'attempt da requisição rate-limited não é gravado'
);

select * from finish();
rollback;
