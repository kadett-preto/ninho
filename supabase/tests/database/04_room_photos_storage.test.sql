-- Ninho — Storage RLS para fotos de cômodos (IDEA.md §7.4).

begin;
select plan(9);

insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'alice-storage@test.local'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bob-storage@test.local');

insert into public.environments (id, owner_id, name, timezone) values
  ('eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Ninho Alice', 'America/Sao_Paulo'),
  ('eeeeeeee-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ninho Bob', 'America/Sao_Paulo');

select ok(
  not (select public from storage.buckets where id = 'room-photos'),
  'bucket room-photos é privado'
);
select is(
  (select file_size_limit from storage.buckets where id = 'room-photos'),
  8388608::bigint,
  'bucket limita upload a 8 MB'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'room-photos'),
  array['image/jpeg']::text[],
  'bucket aceita apenas image/jpeg'
);

select is(
  public.storage_object_environment_id('eeeeeeee-1111-1111-1111-111111111111/rooms/sala.jpg'),
  'eeeeeeee-1111-1111-1111-111111111111'::uuid,
  'helper extrai environment_id do path'
);
select is(
  public.storage_object_environment_id('sem-uuid/rooms/sala.jpg'),
  null::uuid,
  'helper retorna null para path inválido'
);

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';

insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
values (
  'room-photos',
  'eeeeeeee-1111-1111-1111-111111111111/rooms/sala.jpg',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '{"mimetype":"image/jpeg","size":1000}'::jsonb
);

select results_eq(
  $$select count(*)::int from storage.objects where bucket_id = 'room-photos'$$,
  array[1],
  'Alice insere e vê foto do próprio ninho'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    values ('room-photos',
            'eeeeeeee-1111-1111-1111-111111111111/rooms/sala.png',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            '{"mimetype":"image/png","size":1000}'::jsonb)$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'extensão diferente de .jpg é bloqueada'
);

set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';

select results_eq(
  $$select count(*)::int from storage.objects where bucket_id = 'room-photos'$$,
  array[0],
  'Bob não vê foto do ninho da Alice'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    values ('room-photos',
            'eeeeeeee-1111-1111-1111-111111111111/rooms/invasao.jpg',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            '{"mimetype":"image/jpeg","size":1000}'::jsonb)$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'Bob não insere foto no ninho da Alice'
);

select * from finish();
rollback;
