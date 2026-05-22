-- Ninho — RPC transacional para cadastro de ninho + cômodos (TASKS 3.7).

begin;
select plan(7);

insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'alice-rpc@test.local');

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';

select lives_ok(
  $$select public.create_environment_with_rooms(
      'Nosso apê',
      'America/Sao_Paulo',
      '[{"name":"Sala","size_category":"M"},{"name":"Banheiro","size_category":"P"}]'::jsonb
    )$$,
  'RPC cria ninho + cômodos válidos'
);

select results_eq(
  $$select count(*)::int from public.environments where name = 'Nosso apê'$$,
  array[1],
  'environment foi criado'
);

select results_eq(
  $$select count(*)::int from public.rooms where name in ('Sala', 'Banheiro')$$,
  array[2],
  'rooms foram criados na mesma chamada'
);

select results_eq(
  $$select count(*)::int from public.environment_members where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and role = 'owner'$$,
  array[1],
  'trigger criou membership owner'
);

select throws_ok(
  $$select public.create_environment_with_rooms(
      'Ninho inválido',
      'America/Sao_Paulo',
      '[{"name":"Cozinha","size_category":"X"}]'::jsonb
    )$$,
  '22023',
  'Tamanho de cômodo inválido',
  'RPC rejeita tamanho inválido'
);

select results_eq(
  $$select count(*)::int from public.environments where name = 'Ninho inválido'$$,
  array[0],
  'falha em rooms não deixa environment parcial'
);

set local "request.jwt.claims" = '{}';
select throws_ok(
  $$select public.create_environment_with_rooms(
      'Sem sessão',
      'America/Sao_Paulo',
      '[{"name":"Sala","size_category":"M"}]'::jsonb
    )$$,
  '28000',
  'Sem sessão Supabase ativa',
  'RPC exige auth.uid()'
);

select * from finish();
rollback;
