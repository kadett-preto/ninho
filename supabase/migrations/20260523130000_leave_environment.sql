-- Ninho — Fase 11.7 / IDEA.md §5.5: sair de um ninho.
--
-- RPC `leave_environment` SECURITY DEFINER. Regras:
--   * Caller deve ser membro ativo.
--   * Owner único com outros membros: rejeita (precisa transferir antes
--     ou usar request_account_deletion). Errcode 22023.
--   * Owner sem outros membros: arquiva o environment.
--   * Member regular: só marca left_at.
--
-- Audit em todos os caminhos. Idempotência: chamar duas vezes na mesma
-- env devolve already_left=true.

create or replace function public.leave_environment(
  p_environment_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_member record;
  v_others_count int;
  v_env_archived boolean := false;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;
  if p_environment_id is null then
    raise exception 'environment_id obrigatório' using errcode = '22023';
  end if;

  select id, role, left_at into v_member
    from public.environment_members
   where environment_id = p_environment_id
     and user_id = v_user_id;

  if v_member.id is null then
    raise exception 'Você não é membro deste ninho' using errcode = '42501';
  end if;

  if v_member.left_at is not null then
    return jsonb_build_object('already_left', true);
  end if;

  select count(*)::int into v_others_count
    from public.environment_members
   where environment_id = p_environment_id
     and left_at is null
     and user_id <> v_user_id;

  if v_member.role = 'owner' and v_others_count > 0 then
    raise exception 'Transfira a propriedade antes de sair'
      using errcode = '22023';
  end if;

  update public.environment_members
     set left_at = now()
   where id = v_member.id;

  if v_member.role = 'owner' and v_others_count = 0 then
    update public.environments
       set archived_at = now()
     where id = p_environment_id;
    v_env_archived := true;

    insert into public.audit_log (
      environment_id, actor_id, action, target_type, target_id, metadata
    ) values (
      p_environment_id,
      v_user_id,
      'environment.archived',
      'environment',
      p_environment_id,
      jsonb_build_object('reason', 'owner_left_solo')
    );
  end if;

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    p_environment_id,
    v_user_id,
    'environment.member_left',
    'user',
    v_user_id,
    jsonb_build_object(
      'role', v_member.role,
      'env_archived', v_env_archived
    )
  );

  return jsonb_build_object(
    'already_left', false,
    'env_archived', v_env_archived
  );
end;
$$;

revoke all on function public.leave_environment(uuid) from public, anon;
grant execute on function public.leave_environment(uuid) to authenticated;
