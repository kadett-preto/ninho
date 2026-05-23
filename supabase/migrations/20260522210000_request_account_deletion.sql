-- Ninho — Fase 11.3 + 11.4 / LGPD §5.10: soft-delete de conta.
--
-- RPC `request_account_deletion` marca `users.deleted_at` (soft delete),
-- desliga a sessão do caller dos ninhos (environment_members.left_at) e
-- trata o caso owner sem transferir (§5.5):
--   * Se há outros membros ativos: promove o mais antigo a owner.
--   * Se o caller é o único membro ativo: arquiva o environment.
--
-- Auditoria e idempotência:
--   * Audit `user.deletion_request` por chamada.
--   * Audit `environment.owner_auto_promoted` ou `environment.archived`
--     conforme o caso.
--   * Se já está deletado, retorna o snapshot atual sem repetir efeitos.
--
-- Purge real (hard delete em 30d) é responsabilidade de cron futuro;
-- esta migration só ativa o soft delete e o handoff de ownership.

create or replace function public.request_account_deletion()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_already_deleted boolean := false;
  v_envs_promoted int := 0;
  v_envs_archived int := 0;
  v_env record;
  v_new_owner uuid;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  -- Idempotência: se já solicitou exclusão, devolve estado e sai cedo.
  select (deleted_at is not null) into v_already_deleted
    from public.users where id = v_user_id;
  if v_already_deleted then
    return jsonb_build_object(
      'already_deleted', true,
      'envs_promoted', 0,
      'envs_archived', 0
    );
  end if;

  -- Processa ninhos onde o caller é owner.
  for v_env in
    select e.id, e.archived_at
      from public.environments e
      join public.environment_members em
        on em.environment_id = e.id
       and em.user_id = v_user_id
       and em.role = 'owner'
       and em.left_at is null
     where e.archived_at is null
  loop
    -- Outro membro ativo mais antigo (joined_at ASC).
    select user_id into v_new_owner
      from public.environment_members
     where environment_id = v_env.id
       and left_at is null
       and user_id <> v_user_id
     order by joined_at asc
     limit 1;

    if v_new_owner is not null then
      update public.environment_members
         set role = 'owner'
       where environment_id = v_env.id
         and user_id = v_new_owner;
      update public.environments
         set owner_id = v_new_owner
       where id = v_env.id;
      v_envs_promoted := v_envs_promoted + 1;

      insert into public.audit_log (
        environment_id,
        actor_id,
        action,
        target_type,
        target_id,
        metadata
      )
      values (
        v_env.id,
        v_user_id,
        'environment.owner_auto_promoted',
        'user',
        v_new_owner,
        jsonb_build_object('reason', 'account_deletion_request')
      );
    else
      update public.environments
         set archived_at = now()
       where id = v_env.id;
      v_envs_archived := v_envs_archived + 1;

      insert into public.audit_log (
        environment_id,
        actor_id,
        action,
        target_type,
        target_id,
        metadata
      )
      values (
        v_env.id,
        v_user_id,
        'environment.archived',
        'environment',
        v_env.id,
        jsonb_build_object('reason', 'last_member_deletion')
      );
    end if;
  end loop;

  -- Sai de todos os ninhos onde ainda é membro ativo.
  update public.environment_members
     set left_at = now()
   where user_id = v_user_id
     and left_at is null;

  -- Soft delete do usuário.
  update public.users
     set deleted_at = now()
   where id = v_user_id;

  insert into public.audit_log (
    environment_id,
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  )
  values (
    null,
    v_user_id,
    'user.deletion_request',
    'user',
    v_user_id,
    jsonb_build_object(
      'envs_promoted', v_envs_promoted,
      'envs_archived', v_envs_archived
    )
  );

  return jsonb_build_object(
    'already_deleted', false,
    'envs_promoted', v_envs_promoted,
    'envs_archived', v_envs_archived
  );
end;
$$;

revoke all on function public.request_account_deletion() from public, anon;
grant execute on function public.request_account_deletion() to authenticated;

-- Auxiliar: descreve os ninhos onde o caller é owner ativo, p/ UI mostrar
-- aviso antes de confirmar (§5.5). RLS já restringiria, mas centralizar
-- aqui evita roundtrips.
create or replace function public.list_owned_environments()
returns table (
  environment_id uuid,
  name text,
  other_members_count int
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    e.id,
    e.name,
    (
      select count(*)::int
        from public.environment_members em2
       where em2.environment_id = e.id
         and em2.left_at is null
         and em2.user_id <> auth.uid()
    )
  from public.environments e
  join public.environment_members em
    on em.environment_id = e.id
   and em.user_id = auth.uid()
   and em.role = 'owner'
   and em.left_at is null
  where e.archived_at is null;
$$;

revoke all on function public.list_owned_environments() from public, anon;
grant execute on function public.list_owned_environments() to authenticated;
