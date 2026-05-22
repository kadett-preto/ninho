-- Ninho - Fase 10.3/10.4: moderacao persistente do mural.
--
-- Fluxos:
--   * Morador denuncia item do mural como sinal interno MVP.
--   * Autor remove a propria foto do mural (soft hide do feed_event).
--   * Owner oculta ou deleta qualquer item do mural.
--   * Todas as acoes sensiveis passam por RPC para gravar audit_log.

alter table public.feed_events
  add column if not exists hidden_reason text;

create index if not exists feed_events_env_visible_created_idx
  on public.feed_events (environment_id, created_at desc)
  where hidden_at is null;

drop policy if exists feed_events_update_owner_or_actor on public.feed_events;
drop policy if exists feed_events_delete_actor on public.feed_events;

create table if not exists public.feed_event_reports (
  id uuid primary key default gen_random_uuid(),
  feed_event_id uuid not null references public.feed_events(id) on delete cascade,
  environment_id uuid not null references public.environments(id) on delete cascade,
  reporter_id uuid not null references public.users(id) on delete cascade,
  reason text not null default 'inappropriate',
  details text,
  created_at timestamptz not null default now(),
  unique (feed_event_id, reporter_id)
);

create index if not exists feed_event_reports_env_created_idx
  on public.feed_event_reports (environment_id, created_at desc);

alter table public.feed_event_reports enable row level security;

-- Sinal interno MVP: cliente escreve apenas via RPC e nao le a tabela direto.
drop policy if exists feed_event_reports_select_owner_or_reporter on public.feed_event_reports;
drop policy if exists feed_event_reports_insert_member on public.feed_event_reports;
revoke all on public.feed_event_reports from anon, authenticated;

create or replace function public.report_feed_event(
  p_event_id uuid,
  p_reason text default 'inappropriate',
  p_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_event public.feed_events%rowtype;
  v_reason text := left(nullif(btrim(coalesce(p_reason, '')), ''), 80);
  v_details text := left(nullif(btrim(coalesce(p_details, '')), ''), 500);
  v_report_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  if p_event_id is null then
    raise exception 'Item do mural inválido' using errcode = '22023';
  end if;

  select *
    into v_event
    from public.feed_events
   where id = p_event_id
   for update;

  if not found or v_event.hidden_at is not null then
    raise exception 'Item do mural não encontrado' using errcode = '42704';
  end if;

  if not public.is_environment_member(v_event.environment_id) then
    raise exception 'Você não participa deste ninho' using errcode = '42501';
  end if;

  insert into public.feed_event_reports (
    feed_event_id,
    environment_id,
    reporter_id,
    reason,
    details
  )
  values (
    v_event.id,
    v_event.environment_id,
    v_user_id,
    coalesce(v_reason, 'inappropriate'),
    v_details
  )
  on conflict (feed_event_id, reporter_id) do update
     set reason = excluded.reason,
         details = excluded.details
  returning id into v_report_id;

  insert into public.audit_log (
    environment_id,
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  )
  values (
    v_event.environment_id,
    v_user_id,
    'feed.report',
    'feed_event',
    v_event.id,
    jsonb_build_object(
      'reason', coalesce(v_reason, 'inappropriate'),
      'event_type', v_event.event_type,
      'report_id', v_report_id
    )
  );

  return jsonb_build_object('report_id', v_report_id);
end;
$$;

create or replace function public.moderate_feed_event(
  p_event_id uuid,
  p_action text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_event public.feed_events%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_reason text := left(nullif(btrim(coalesce(p_reason, '')), ''), 160);
  v_is_owner boolean;
  v_is_actor boolean;
  v_has_photo boolean;
  v_audit_action text;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  if p_event_id is null then
    raise exception 'Item do mural inválido' using errcode = '22023';
  end if;

  if v_action not in ('delete_photo', 'hide', 'delete') then
    raise exception 'Ação de moderação inválida' using errcode = '22023';
  end if;

  select *
    into v_event
    from public.feed_events
   where id = p_event_id
   for update;

  if not found then
    raise exception 'Item do mural não encontrado' using errcode = '42704';
  end if;

  if not public.is_environment_member(v_event.environment_id) then
    raise exception 'Você não participa deste ninho' using errcode = '42501';
  end if;

  v_is_owner := public.is_environment_owner(v_event.environment_id);
  v_is_actor := v_event.actor_id = v_user_id;
  v_has_photo := coalesce(v_event.payload ? 'photo_path', false)
    and nullif(v_event.payload->>'photo_path', '') is not null;

  if v_action = 'delete_photo' then
    if not v_is_actor or not v_has_photo then
      raise exception 'Apenas o autor pode remover a própria foto' using errcode = '42501';
    end if;

    update public.feed_events
       set hidden_at = coalesce(hidden_at, now()),
           hidden_by = v_user_id,
           hidden_reason = coalesce(v_reason, 'author_deleted_photo')
     where id = v_event.id;

    v_audit_action := 'feed.photo.delete';
  elsif v_action = 'hide' then
    if not v_is_owner then
      raise exception 'Apenas o owner pode moderar o mural' using errcode = '42501';
    end if;

    update public.feed_events
       set hidden_at = coalesce(hidden_at, now()),
           hidden_by = v_user_id,
           hidden_reason = coalesce(v_reason, 'owner_hidden')
     where id = v_event.id;

    v_audit_action := 'feed.hide';
  else
    if not v_is_owner then
      raise exception 'Apenas o owner pode moderar o mural' using errcode = '42501';
    end if;

    delete from public.feed_events
     where id = v_event.id;

    v_audit_action := 'feed.delete';
  end if;

  insert into public.audit_log (
    environment_id,
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  )
  values (
    v_event.environment_id,
    v_user_id,
    v_audit_action,
    'feed_event',
    v_event.id,
    jsonb_build_object(
      'reason', v_reason,
      'event_type', v_event.event_type,
      'had_photo', v_has_photo
    )
  );

  return jsonb_build_object('action', v_action, 'event_id', v_event.id);
end;
$$;

revoke all on function public.report_feed_event(uuid, text, text) from public;
revoke all on function public.moderate_feed_event(uuid, text, text) from public;
revoke all on function public.report_feed_event(uuid, text, text) from anon;
revoke all on function public.moderate_feed_event(uuid, text, text) from anon;
grant execute on function public.report_feed_event(uuid, text, text) to authenticated;
grant execute on function public.moderate_feed_event(uuid, text, text) to authenticated;
