-- Ninho — Fase 11.8 / IDEA.md §5.2 + §5.5: configurações do ninho.
--
-- RPCs SECURITY DEFINER:
--
--   * `update_environment_name(env_id, name)` — owner only. Sanitiza
--     trim + 60 chars max. Audit `environment.renamed`.
--
--   * `remove_member(env_id, user_id)` — owner only. Rejeita auto-remoção
--     (use leave_environment) e tentativa de remover outro owner (precisa
--     transferir primeiro). Marca `left_at`. Audit
--     `environment.member_removed`.

create or replace function public.update_environment_name(
  p_environment_id uuid,
  p_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := auth.uid();
  v_clean text;
begin
  if v_caller is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;
  if not public.is_environment_owner(p_environment_id) then
    raise exception 'Apenas o owner pode renomear o ninho'
      using errcode = '42501';
  end if;
  v_clean := trim(coalesce(p_name, ''));
  if v_clean = '' then
    raise exception 'nome obrigatório' using errcode = '22023';
  end if;
  if length(v_clean) > 60 then
    v_clean := substr(v_clean, 1, 60);
  end if;

  update public.environments
     set name = v_clean
   where id = p_environment_id;

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    p_environment_id,
    v_caller,
    'environment.renamed',
    'environment',
    p_environment_id,
    jsonb_build_object('new_name', v_clean)
  );
end;
$$;

revoke all on function public.update_environment_name(uuid, text)
  from public, anon;
grant execute on function public.update_environment_name(uuid, text)
  to authenticated;


create or replace function public.remove_member(
  p_environment_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := auth.uid();
  v_target_role text;
begin
  if v_caller is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;
  if p_environment_id is null or p_user_id is null then
    raise exception 'parâmetros obrigatórios' using errcode = '22023';
  end if;
  if not public.is_environment_owner(p_environment_id) then
    raise exception 'Apenas o owner pode remover membros'
      using errcode = '42501';
  end if;
  if p_user_id = v_caller then
    raise exception 'Para sair do próprio ninho, use leave_environment'
      using errcode = '22023';
  end if;

  select role::text into v_target_role
    from public.environment_members
   where environment_id = p_environment_id
     and user_id = p_user_id
     and left_at is null;

  if v_target_role is null then
    raise exception 'Membro não encontrado' using errcode = '22023';
  end if;
  if v_target_role = 'owner' then
    raise exception 'Outro owner ativo não pode ser removido — transfira a propriedade primeiro'
      using errcode = '22023';
  end if;

  update public.environment_members
     set left_at = now()
   where environment_id = p_environment_id
     and user_id = p_user_id;

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    p_environment_id,
    v_caller,
    'environment.member_removed',
    'user',
    p_user_id,
    jsonb_build_object('removed_role', v_target_role)
  );
end;
$$;

revoke all on function public.remove_member(uuid, uuid) from public, anon;
grant execute on function public.remove_member(uuid, uuid) to authenticated;
