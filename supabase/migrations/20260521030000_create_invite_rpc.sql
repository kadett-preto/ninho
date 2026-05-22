-- Ninho — Fase 4.2: RPC para criação de convite.
-- IDEA.md §5.3 (convite) e §7.3 (segurança de convite).
--
-- Chamada pela Edge Function `create-invite`, que:
--   1. Gera token aleatório >=128 bits (32 bytes via crypto.getRandomValues).
--   2. Calcula sha-256 do token.
--   3. Passa o HASH como p_token_hash. O token claro nunca chega ao banco.
--
-- SECURITY DEFINER porque a tabela `invites` bloqueia INSERT de cliente
-- (§7.3, defesa em profundidade). Validamos owner via is_environment_owner()
-- antes de inserir.

create or replace function public.create_invite(
  p_environment_id uuid,
  p_token_hash text,
  p_ttl_days integer default 7
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_invite_id uuid;
  v_expires_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  if p_environment_id is null then
    raise exception 'environment_id obrigatório' using errcode = '22023';
  end if;

  if not public.is_environment_owner(p_environment_id) then
    raise exception 'Apenas o owner pode gerar convites' using errcode = '42501';
  end if;

  if p_token_hash is null or char_length(p_token_hash) < 32 then
    raise exception 'Token hash inválido' using errcode = '22023';
  end if;

  if p_ttl_days is null or p_ttl_days < 1 or p_ttl_days > 30 then
    raise exception 'TTL inválido' using errcode = '22023';
  end if;

  v_expires_at := now() + (p_ttl_days || ' days')::interval;

  insert into public.invites (environment_id, token_hash, created_by, expires_at)
  values (p_environment_id, p_token_hash, v_user_id, v_expires_at)
  returning id into v_invite_id;

  insert into public.audit_log (environment_id, actor_id, action, target_type, target_id)
  values (p_environment_id, v_user_id, 'invite.create', 'invite', v_invite_id);

  return jsonb_build_object(
    'invite_id', v_invite_id,
    'expires_at', v_expires_at
  );
end;
$$;

revoke all on function public.create_invite(uuid, text, integer)
  from public, anon;
grant execute on function public.create_invite(uuid, text, integer)
  to authenticated;

-- Revogação de convite ativo pelo owner. Idempotente: se já revogado/usado,
-- não falha mas retorna o estado atual.
create or replace function public.revoke_invite(
  p_invite_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_environment_id uuid;
  v_already_done boolean;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  select environment_id, (used_at is not null or revoked_at is not null)
    into v_environment_id, v_already_done
  from public.invites
  where id = p_invite_id;

  if v_environment_id is null then
    raise exception 'Convite não encontrado' using errcode = '42704';
  end if;

  if not public.is_environment_owner(v_environment_id) then
    raise exception 'Apenas o owner pode revogar convites' using errcode = '42501';
  end if;

  if v_already_done then
    return jsonb_build_object('invite_id', p_invite_id, 'changed', false);
  end if;

  update public.invites
     set revoked_at = now(),
         revoked_by = v_user_id
   where id = p_invite_id;

  insert into public.audit_log (environment_id, actor_id, action, target_type, target_id)
  values (v_environment_id, v_user_id, 'invite.revoke', 'invite', p_invite_id);

  return jsonb_build_object('invite_id', p_invite_id, 'changed', true);
end;
$$;

revoke all on function public.revoke_invite(uuid) from public, anon;
grant execute on function public.revoke_invite(uuid) to authenticated;
