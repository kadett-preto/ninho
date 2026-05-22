-- Ninho — Fase 4.5: RPC para PREVIEW de convite (sem consumir).
-- IDEA.md §5.3 (convite), §7.3 (segurança de convite), §7.6 (não confiar
-- em dado do cliente).
--
-- Edge Function `preview-invite` calcula sha-256 do token claro e chama
-- este RPC. Retorna metadados do ninho (nome, criado_em, n_membros,
-- nomes_membros, n_cômodos, streak do ambiente, already_member) para a
-- tela `AcceptInviteScreen` exibir o "card de boas-vindas" antes de
-- aceitar. NÃO marca o convite como usado nem cria membership.
--
-- SECURITY DEFINER porque:
--   * `invites` tem SELECT bloqueado para não-owner do ninho.
--   * `environment_members` SELECT é restrito ao ninho do usuário; convidado
--     ainda não é membro, então não consegue ler pelo caminho normal.
--   * Mesmas razões aplicáveis a `environments`, `rooms`, `streaks`.
-- Tudo é checado aqui dentro a partir do hash do token.
--
-- Rate-limit: mesma janela que `accept_invite` (10/min por usuário) — mas
-- usamos uma ação separada (`invite.preview_attempt`) para não acoplar:
-- preview pode ser tentado várias vezes (refresh, navegar), mas ainda
-- queremos limite anti-scraping.

create or replace function public.preview_invite(
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
  v_env record;
  v_member_count integer;
  v_member_names text[];
  v_room_count integer;
  v_streak integer;
  v_already_member boolean;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  if p_token_hash is null or char_length(p_token_hash) < 32 then
    raise exception 'Token inválido' using errcode = '22023';
  end if;

  -- §7.3 rate-limit: 30 tentativas/min/usuário. Mais frouxo que accept
  -- porque preview é leitura idempotente; ainda protege contra scraping.
  select count(*)::int into v_recent_attempts
    from public.audit_log
   where actor_id = v_user_id
     and action = 'invite.preview_attempt'
     and created_at > now() - interval '1 minute';

  if v_recent_attempts >= 30 then
    raise exception 'Muitas tentativas, aguarde um minuto' using errcode = '54000';
  end if;

  insert into public.audit_log (actor_id, action, target_type, metadata)
  values (v_user_id, 'invite.preview_attempt', 'invite', '{}'::jsonb);

  -- Lookup por hash. Sem FOR UPDATE — não vamos mutar a linha.
  select id, environment_id, expires_at, used_at, revoked_at
    into v_invite
    from public.invites
   where token_hash = p_token_hash;

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

  select id, name, created_at
    into v_env
    from public.environments
   where id = v_invite.environment_id;

  -- Membros ativos do ninho. left_at IS NULL exclui quem saiu.
  -- Ordenação por joined_at p/ apresentação estável; limitamos a 8 nomes
  -- p/ não explodir o payload.
  select count(*)::int into v_member_count
    from public.environment_members
   where environment_id = v_env.id
     and left_at is null;

  select coalesce(array_agg(display_name order by joined_at), array[]::text[])
    into v_member_names
    from (
      select coalesce(u.display_name, 'Morador') as display_name, m.joined_at
        from public.environment_members m
        join public.users u on u.id = m.user_id
       where m.environment_id = v_env.id
         and m.left_at is null
       order by m.joined_at
       limit 8
    ) ordered;

  select count(*)::int into v_room_count
    from public.rooms
   where environment_id = v_env.id;

  -- Streak do ambiente (não do usuário). Pode não existir ainda → 0.
  select coalesce(current_count, 0) into v_streak
    from public.streaks
   where environment_id = v_env.id
     and kind = 'environment'
     and user_id is null
   limit 1;

  v_streak := coalesce(v_streak, 0);

  -- Pré-flag de idempotência. Tela pode mostrar copy "você já é membro"
  -- antes do tap em "Entrar".
  select exists(
    select 1 from public.environment_members
     where environment_id = v_env.id
       and user_id = v_user_id
       and left_at is null
  ) into v_already_member;

  return jsonb_build_object(
    'environment_id', v_env.id,
    'environment_name', v_env.name,
    'environment_created_at', v_env.created_at,
    'member_count', v_member_count,
    'member_names', to_jsonb(v_member_names),
    'room_count', v_room_count,
    'environment_streak', v_streak,
    'already_member', v_already_member
  );
end;
$$;

revoke all on function public.preview_invite(text) from public, anon;
grant execute on function public.preview_invite(text) to authenticated;
