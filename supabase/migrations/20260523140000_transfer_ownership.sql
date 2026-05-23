-- Ninho — Fase 11.6 / IDEA.md §5.5: transferir ownership manual.
--
-- Dois RPCs SECURITY DEFINER:
--
--   * `list_environment_members(env_id)` — retorna user_id + display_name
--     + role + joined_at para todos os membros ativos do ninho. Caller
--     deve ser membro (qualquer papel). Permite que a UI mostre os
--     candidatos a novo owner sem precisar relaxar a RLS de public.users.
--
--   * `transfer_ownership(env_id, new_owner_id)` — owner only. Valida
--     que new_owner é membro ativo (≠ caller). Faz o swap em
--     environment_members.role + environments.owner_id numa única
--     transação. Audit `environment.ownership_transferred`.

create or replace function public.list_environment_members(
  p_environment_id uuid
)
returns table (
  user_id uuid,
  display_name text,
  role public.environment_role,
  joined_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    em.user_id,
    u.display_name,
    em.role,
    em.joined_at
  from public.environment_members em
  join public.users u on u.id = em.user_id
  where em.environment_id = p_environment_id
    and em.left_at is null
    and exists (
      select 1 from public.environment_members me
       where me.environment_id = p_environment_id
         and me.user_id = auth.uid()
         and me.left_at is null
    )
  order by em.joined_at asc;
$$;

revoke all on function public.list_environment_members(uuid)
  from public, anon;
grant execute on function public.list_environment_members(uuid)
  to authenticated;


create or replace function public.transfer_ownership(
  p_environment_id uuid,
  p_new_owner_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := auth.uid();
  v_caller_role text;
  v_new_role text;
begin
  if v_caller is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;
  if p_environment_id is null or p_new_owner_id is null then
    raise exception 'parâmetros obrigatórios' using errcode = '22023';
  end if;
  if p_new_owner_id = v_caller then
    raise exception 'novo owner deve ser diferente do caller'
      using errcode = '22023';
  end if;

  select role::text into v_caller_role
    from public.environment_members
   where environment_id = p_environment_id
     and user_id = v_caller
     and left_at is null;

  if v_caller_role is null then
    raise exception 'Você não é membro deste ninho'
      using errcode = '42501';
  end if;
  if v_caller_role <> 'owner' then
    raise exception 'Apenas o owner pode transferir o ninho'
      using errcode = '42501';
  end if;

  select role::text into v_new_role
    from public.environment_members
   where environment_id = p_environment_id
     and user_id = p_new_owner_id
     and left_at is null;

  if v_new_role is null then
    raise exception 'O novo owner precisa ser membro ativo do ninho'
      using errcode = '22023';
  end if;

  update public.environment_members
     set role = 'owner'
   where environment_id = p_environment_id
     and user_id = p_new_owner_id;

  update public.environment_members
     set role = 'member'
   where environment_id = p_environment_id
     and user_id = v_caller;

  update public.environments
     set owner_id = p_new_owner_id
   where id = p_environment_id;

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    p_environment_id,
    v_caller,
    'environment.ownership_transferred',
    'user',
    p_new_owner_id,
    jsonb_build_object('previous_owner', v_caller)
  );

  return jsonb_build_object(
    'previous_owner', v_caller,
    'new_owner', p_new_owner_id
  );
end;
$$;

revoke all on function public.transfer_ownership(uuid, uuid)
  from public, anon;
grant execute on function public.transfer_ownership(uuid, uuid)
  to authenticated;
