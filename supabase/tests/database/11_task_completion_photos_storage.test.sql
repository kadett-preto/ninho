-- Ninho — Storage RLS para fotos de conclusão (IDEA.md §7.4).

begin;
select plan(8);

insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'alice-completion-photo@test.local'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bob-completion-photo@test.local');

insert into public.environments (id, owner_id, name, timezone) values
  ('eeeeeeee-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Ninho Alice Foto', 'America/Sao_Paulo'),
  ('eeeeeeee-4444-4444-4444-444444444444', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ninho Bob Foto', 'America/Sao_Paulo');

select ok(
  not (select public from storage.buckets where id = 'task-completion-photos'),
  'bucket task-completion-photos é privado'
);
select is(
  (select file_size_limit from storage.buckets where id = 'task-completion-photos'),
  8388608::bigint,
  'bucket limita upload a 8 MB'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'task-completion-photos'),
  array['image/jpeg']::text[],
  'bucket aceita apenas image/jpeg'
);

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';

insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
values (
  'task-completion-photos',
  'eeeeeeee-3333-3333-3333-333333333333/task-completions/cccccccc-3333-3333-3333-333333333333/alice.jpg',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '{"mimetype":"image/jpeg","size":1000}'::jsonb
);

select results_eq(
  $$select count(*)::int from storage.objects where bucket_id = 'task-completion-photos'$$,
  array[1],
  'Alice insere e vê foto de conclusão do próprio ninho'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    values ('task-completion-photos',
            'eeeeeeee-3333-3333-3333-333333333333/task-completions/cccccccc-3333-3333-3333-333333333333/alice.png',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            '{"mimetype":"image/png","size":1000}'::jsonb)$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'extensão diferente de .jpg é bloqueada'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    values ('task-completion-photos',
            'eeeeeeee-3333-3333-3333-333333333333/rooms/sala.jpg',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            '{"mimetype":"image/jpeg","size":1000}'::jsonb)$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'prefixo fora de task-completions é bloqueado'
);

set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';

select results_eq(
  $$select count(*)::int from storage.objects where bucket_id = 'task-completion-photos'$$,
  array[0],
  'Bob não vê foto do ninho da Alice'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    values ('task-completion-photos',
            'eeeeeeee-3333-3333-3333-333333333333/task-completions/cccccccc-3333-3333-3333-333333333333/invasao.jpg',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            '{"mimetype":"image/jpeg","size":1000}'::jsonb)$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'Bob não insere foto no ninho da Alice'
);

select * from finish();
rollback;
