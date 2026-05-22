-- Ninho — Fase 4.3: RPC para aceitar convite.
-- IDEA.md §5.3 (convite) e §7.3 (segurança de convite).
--
-- Edge Function `accept-invite`:
--   1. Recebe token claro do convidado autenticado.
--   2. Calcula sha-256 hex → p_token_hash.
--   3. Chama este RPC, que faz validação + insert atômico de membership.
--
-- SECURITY DEFINER porque:
--   * `invites` tem SELECT por owner apenas — convidado não-membro não enxerga
--     a linha pelo path normal.
--   * `environment_members` INSERT exige is_environment_owner() — convidado
--     também não passa.
-- Toda a checagem de autorização ocorre aqui dentro com base no token.

create or replace function public.accept_invite(
  p_token_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_invite record;
  v_recent_attempts integer;
  v_environment_name text;
  v_already_member boolean;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  if p_token_hash is null or char_length(p_token_hash) < 32 then
    raise exception 'Token inválido' using errcode = '22023';
  end if;

  -- §7.3 rate limit: máx 10 tentativas por usuário nos últimos 60 segundos.
  -- Tokens têm 256 bits de entropia, brute-force prático é nulo; o limite
  -- protege contra abuso de recurso (replay em massa, scraping).
  select count(*)::int into v_recent_attempts
    from public.audit_log
   where actor_id = v_user_id
     and action = 'invite.accept_attempt'
     and created_at > now() - interval '1 minute';

  if v_recent_attempts >= 10 then
    raise exception 'Muitas tentativas, aguarde um minuto' using errcode = '54000';
  end if;

  insert into public.audit_log (actor_id, action, target_type, metadata)
  values (v_user_id, 'invite.accept_attempt', 'invite', '{}'::jsonb);

  -- Lookup por hash. Lock-for-update evita race entre dois convidados usando
  -- o mesmo token simultaneamente — um vence, outro vê used_at.
  select id, environment_id, expires_at, used_at, revoked_at
    into v_invite
    from public.invites
   where token_hash = p_token_hash
   for update;

  if v_invite.id is null then
    raise exception 'Convite não encontrado' using errcode = '42704';
  end if;

  if v_invite.revoked_at is not null then
    raise exception 'Convite revogado' using errcode = '22023';
  end if;

  if v_invite.used_at is not null then
    raise exception 'Convite já utilizado' using errcode = '22023';
  end if;

  if v_invite.expires_at <= now() then
    raise exception 'Convite expirado' using errcode = '22023';
  end if;

  -- Idempotência defensiva: se o usuário já é membro ativo deste ninho
  -- (entrou por outro caminho, reativação etc.), só marca o convite como
  -- usado e retorna sucesso. Evita falhar com unique violation no insert.
  select exists(
    select 1 from public.environment_members
     where environment_id = v_invite.environment_id
       and user_id = v_user_id
       and left_at is null
  ) into v_already_member;

  if not v_already_member then
    insert into public.environment_members (environment_id, user_id, role)
    values (v_invite.environment_id, v_user_id, 'member');
  end if;

  update public.invites
     set used_at = now(),
         used_by = v_user_id
   where id = v_invite.id;

  select name into v_environment_name
    from public.environments where id = v_invite.environment_id;

  insert into public.audit_log
    (environment_id, actor_id, action, target_type, target_id)
  values
    (v_invite.environment_id, v_user_id, 'invite.accept', 'invite', v_invite.id);

  return jsonb_build_object(
    'environment_id', v_invite.environment_id,
    'environment_name', v_environment_name,
    'already_member', v_already_member
  );
end;
$$;

revoke all on function public.accept_invite(text) from public, anon;
grant execute on function public.accept_invite(text) to authenticated;
