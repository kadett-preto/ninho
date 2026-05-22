-- Ninho — Fase 3.7: criação transacional de ninho + cômodos.
-- Chamado pela Edge Function `create-environment`. SECURITY INVOKER mantém RLS
-- ativa e usa auth.uid() do JWT do usuário.

create or replace function public.create_environment_with_rooms(
  p_name text,
  p_timezone text,
  p_rooms jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_environment_id uuid;
  v_room jsonb;
  v_room_id uuid;
  v_room_name text;
  v_room_size text;
  v_room_count integer;
  v_created_rooms jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  p_name := btrim(coalesce(p_name, ''));
  p_timezone := btrim(coalesce(p_timezone, ''));

  if p_name = '' or char_length(p_name) > 80 then
    raise exception 'Nome do ninho inválido' using errcode = '22023';
  end if;

  if p_timezone = '' or char_length(p_timezone) > 64 then
    raise exception 'Fuso horário inválido' using errcode = '22023';
  end if;

  if p_rooms is null or jsonb_typeof(p_rooms) <> 'array' then
    raise exception 'Cômodos inválidos' using errcode = '22023';
  end if;

  v_room_count := jsonb_array_length(p_rooms);
  if v_room_count < 1 or v_room_count > 20 then
    raise exception 'Informe entre 1 e 20 cômodos' using errcode = '22023';
  end if;

  insert into public.environments (owner_id, name, timezone)
  values (v_user_id, p_name, p_timezone)
  returning id into v_environment_id;

  for v_room in select value from jsonb_array_elements(p_rooms)
  loop
    v_room_name := btrim(coalesce(v_room->>'name', ''));
    v_room_size := upper(btrim(coalesce(v_room->>'size_category', '')));

    if v_room_name = '' or char_length(v_room_name) > 80 then
      raise exception 'Nome de cômodo inválido' using errcode = '22023';
    end if;

    if v_room_size not in ('P', 'M', 'G') then
      raise exception 'Tamanho de cômodo inválido' using errcode = '22023';
    end if;

    insert into public.rooms (environment_id, name, size_category)
    values (v_environment_id, v_room_name, v_room_size::public.room_size)
    returning id into v_room_id;

    v_created_rooms := v_created_rooms || jsonb_build_array(
      jsonb_build_object('id', v_room_id, 'name', v_room_name)
    );
  end loop;

  return jsonb_build_object(
    'environment_id', v_environment_id,
    'rooms', v_created_rooms
  );
end;
$$;

revoke all on function public.create_environment_with_rooms(text, text, jsonb)
  from public, anon;
grant execute on function public.create_environment_with_rooms(text, text, jsonb)
  to authenticated;
