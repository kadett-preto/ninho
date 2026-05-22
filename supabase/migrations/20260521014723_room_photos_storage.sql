-- Ninho — Fase 3: fotos opcionais dos cômodos.
-- Bucket privado. Clientes autenticados podem subir/ler objetos apenas dentro
-- da pasta do ninho de que participam: {environment_id}/rooms/{arquivo}.jpg.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'room-photos',
  'room-photos',
  false,
  8388608,
  array['image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.storage_object_environment_id(object_name text)
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

drop policy if exists room_photos_select_member on storage.objects;
create policy room_photos_select_member
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'room-photos'
    and public.is_environment_member(public.storage_object_environment_id(name))
  );

drop policy if exists room_photos_insert_member on storage.objects;
create policy room_photos_insert_member
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'room-photos'
    and lower(name) like '%.jpg'
    and public.is_environment_member(public.storage_object_environment_id(name))
  );
