-- Ninho — Fase 4.2: RPC `create_invite` + `revoke_invite`.
-- IDEA.md §5.3 + §7.3 — validar:
--   * Owner pode gerar convite; hash chega como passado.
--   * Member do mesmo ninho NÃO pode gerar.
--   * Não-membro NÃO pode gerar (mensagem genérica de owner-only — RLS isola).
--   * Sem sessão → erro.
--   * Hash curto / TTL fora do range → erro 22023.
--   * Revogar: owner consegue, member não, idempotência ok.
--   * audit_log recebe entradas correspondentes.

begin;
select plan(14);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'member@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'outsider@test.local');

-- Owner cria ninho (trigger criou membership owner).
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';

insert into public.environments (id, owner_id, name, timezone)
values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Ninho A', 'America/Sao_Paulo');

-- Promove membro como `member` manualmente para teste de papel.
set local role postgres;
insert into public.environment_members (environment_id, user_id, role)
values ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'member');

-- ============================================================
-- 1) Owner gera convite com sucesso.
-- ============================================================
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';

select lives_ok(
  $$select public.create_invite(
      'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
      repeat('a', 64),
      7
    )$$,
  'owner consegue gerar convite'
);

select results_eq(
  $$select count(*)::int from public.invites
      where environment_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  array[1],
  'invite foi inserido'
);

select results_eq(
  $$select token_hash from public.invites
      where environment_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  array[repeat('a', 64)],
  'token_hash bate com o passado'
);

select results_eq(
  $$select count(*)::int from public.audit_log
      where action = 'invite.create' and actor_id = '11111111-1111-1111-1111-111111111111'$$,
  array[1],
  'audit_log registrou criação do convite'
);

-- ============================================================
-- 2) Member NÃO pode gerar convite.
-- ============================================================
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';

select throws_ok(
  $$select public.create_invite(
      'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
      repeat('b', 64),
      7
    )$$,
  '42501',
  'Apenas o owner pode gerar convites',
  'member é rejeitado'
);

-- ============================================================
-- 3) Outsider (não-membro) também é rejeitado.
-- ============================================================
set local "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333"}';

select throws_ok(
  $$select public.create_invite(
      'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
      repeat('c', 64),
      7
    )$$,
  '42501',
  'Apenas o owner pode gerar convites',
  'outsider é rejeitado (sem revelar existência do ninho)'
);

-- ============================================================
-- 4) Sem sessão → 28000.
-- ============================================================
set local "request.jwt.claims" = '{}';

select throws_ok(
  $$select public.create_invite(
      'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
      repeat('a', 64),
      7
    )$$,
  '28000',
  'Sem sessão Supabase ativa',
  'RPC exige auth.uid()'
);

-- ============================================================
-- 5) Hash curto → 22023.
-- ============================================================
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';

select throws_ok(
  $$select public.create_invite(
      'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
      'short',
      7
    )$$,
  '22023',
  'Token hash inválido',
  'hash < 32 chars é rejeitado'
);

-- ============================================================
-- 6) TTL inválido → 22023.
-- ============================================================
select throws_ok(
  $$select public.create_invite(
      'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
      repeat('a', 64),
      99
    )$$,
  '22023',
  'TTL inválido',
  'TTL > 30 é rejeitado'
);

-- Captura invite_id (postgres bypassa RLS) para usos abaixo onde member
-- não consegue ver a linha via SELECT.
set local role postgres;
select set_config(
  'test.invite_id',
  id::text,
  true
) from public.invites
where environment_id = 'aaaaaaaa-0000-0000-0000-000000000001'
limit 1;

-- ============================================================
-- 7) Revoke: owner consegue.
-- ============================================================
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';

select results_eq(
  $$select (public.revoke_invite(current_setting('test.invite_id')::uuid)->>'changed')::boolean$$,
  array[true],
  'owner revoga convite ativo'
);

select results_eq(
  $$select count(*)::int from public.invites
      where environment_id = 'aaaaaaaa-0000-0000-0000-000000000001'
        and revoked_at is not null$$,
  array[1],
  'revoked_at foi populado'
);

-- ============================================================
-- 8) Revoke idempotente: re-chamar não falha.
-- ============================================================
select results_eq(
  $$select (public.revoke_invite(current_setting('test.invite_id')::uuid)->>'changed')::boolean$$,
  array[false],
  'revoke já revogado é no-op'
);

-- ============================================================
-- 9) Member não pode revogar.
-- ============================================================
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';

select throws_ok(
  $$select public.revoke_invite(current_setting('test.invite_id')::uuid)$$,
  '42501',
  'Apenas o owner pode revogar convites',
  'member não revoga'
);

-- ============================================================
-- 10) Revoke de invite inexistente → 42704.
-- ============================================================
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';

select throws_ok(
  $$select public.revoke_invite('00000000-0000-0000-0000-000000000000'::uuid)$$,
  '42704',
  'Convite não encontrado',
  'invite_id inexistente é rejeitado'
);

select * from finish();
rollback;
