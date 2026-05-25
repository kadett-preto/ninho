-- Ninho — Fase 11.1: avatar de usuário + locale editável.
-- Bucket privado `user-avatars`. Cada usuário só lê/escreve em
-- `<auth.uid>/avatar.jpg` (um avatar por conta). RLS em storage.objects.

alter table public.users
  add column if not exists avatar_path text;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'user-avatars',
  'user-avatars',
  false,
  4194304,
  array['image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Extrai uuid do primeiro segmento do path (`<uuid>/avatar.jpg`).
create or replace function public.storage_object_user_id(object_name text)
returns uuid
language sql
stable
set search_path = ''
as $$
  select case
    when (storage.foldername(object_name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(object_name))[1])::uuid
    else null
  end;
$$;

drop policy if exists user_avatars_select_own on storage.objects;
create policy user_avatars_select_own
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'user-avatars'
    and public.storage_object_user_id(name) = auth.uid()
  );

drop policy if exists user_avatars_insert_own on storage.objects;
create policy user_avatars_insert_own
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'user-avatars'
    and lower(name) like '%.jpg'
    and public.storage_object_user_id(name) = auth.uid()
  );

drop policy if exists user_avatars_update_own on storage.objects;
create policy user_avatars_update_own
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'user-avatars'
    and public.storage_object_user_id(name) = auth.uid()
  )
  with check (
    bucket_id = 'user-avatars'
    and public.storage_object_user_id(name) = auth.uid()
  );

drop policy if exists user_avatars_delete_own on storage.objects;
create policy user_avatars_delete_own
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'user-avatars'
    and public.storage_object_user_id(name) = auth.uid()
  );
