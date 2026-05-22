-- Ninho — Fase 7.5: liga evaluate_environment_streaks ao notify-trigger.
-- Quando streak quebra (user ou environment), enfileira POST via pg_net
-- para o Edge Function `notify-trigger` com event=streak_broken.

-- ============================================================
-- dispatch_notify_event helper
-- ============================================================
-- Não bloqueia o caller (pg_net.http_post é assíncrono). Falha silenciosa
-- em dev local quando service_role_key não está configurado.

create or replace function public.dispatch_notify_event(
  p_environment_id uuid,
  p_event text,
  p_target_user_ids uuid[] default null,
  p_data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_service_role text;
  v_body jsonb;
begin
  v_url := coalesce(
    current_setting('app.settings.supabase_url', true),
    'http://kong:8000'
  );
  v_service_role := coalesce(
    current_setting('app.settings.service_role_key', true),
    ''
  );
  if v_service_role = '' then
    return;
  end if;

  v_body := jsonb_build_object(
    'event', p_event,
    'environment_id', p_environment_id,
    'data', p_data
  );
  if p_target_user_ids is not null then
    v_body := v_body ||
      jsonb_build_object('target_user_ids', to_jsonb(p_target_user_ids));
  end if;

  perform extensions.http_post(
    url := v_url || '/functions/v1/notify-trigger',
    headers := jsonb_build_object(
      'authorization', 'Bearer ' || v_service_role,
      'content-type', 'application/json'
    ),
    body := v_body,
    timeout_milliseconds := 15000
  );
exception
  when undefined_function then null;
  when undefined_table then null;
  when insufficient_privilege then null;
  when others then null;
end;
$$;

revoke all on function public.dispatch_notify_event(uuid, text, uuid[], jsonb)
  from public, anon, authenticated;

-- ============================================================
-- evaluate_environment_streaks v2 — agora dispara notif em broken.
-- ============================================================
-- Mantém todo comportamento original; adiciona dispatch_notify_event em
-- duas situações: (1) user streak rebaixado a 0; (2) env streak a 0.

create or replace function public.evaluate_environment_streaks(
  p_environment_id uuid,
  p_evaluation_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz text;
  v_day date;
  v_month_key text;
  v_vacation boolean;
  v_user record;
  v_expected_count integer;
  v_completed_count integer;
  v_any_user_missed boolean := false;
  v_user_outcomes jsonb := '{}'::jsonb;
  v_env_outcome text;
  v_env_streak public.streaks%rowtype;
  v_user_streak public.streaks%rowtype;
  v_users_processed integer := 0;
  v_freezes_left integer;
  v_current integer;
  v_best integer;
  v_month_resets jsonb := '{}'::jsonb;
  v_broken_users uuid[] := array[]::uuid[];
begin
  select timezone into v_tz
    from public.environments
   where id = p_environment_id;
  if v_tz is null then
    raise exception 'Ninho não encontrado' using errcode = '42704';
  end if;

  v_day := coalesce(
    p_evaluation_date,
    ((now() at time zone v_tz)::date - 1)
  );
  v_month_key := to_char(v_day, 'YYYY-MM');

  select exists (
    select 1 from public.vacation_periods
     where environment_id = p_environment_id
       and started_on <= v_day
       and (ended_on is null or ended_on >= v_day)
  ) into v_vacation;

  select * into v_env_streak
    from public.streaks
   where environment_id = p_environment_id and kind = 'environment';
  if not found then
    insert into public.streaks (environment_id, user_id, kind, freezes_month_key)
    values (p_environment_id, null, 'environment', v_month_key)
    returning * into v_env_streak;
  end if;

  if v_vacation then
    update public.streaks
       set last_evaluated_at = now(),
           freezes_left_month = case
             when freezes_month_key is distinct from v_month_key then 2
             else freezes_left_month
           end,
           freezes_month_key = v_month_key
     where environment_id = p_environment_id;

    return jsonb_build_object(
      'environment_id', p_environment_id,
      'evaluated_day', v_day,
      'paused', true,
      'reason', 'vacation'
    );
  end if;

  for v_user in
    select user_id
      from public.environment_members
     where environment_id = p_environment_id and left_at is null
  loop
    v_users_processed := v_users_processed + 1;

    select * into v_user_streak
      from public.streaks
     where environment_id = p_environment_id
       and kind = 'user'
       and user_id = v_user.user_id;
    if not found then
      insert into public.streaks (environment_id, user_id, kind, freezes_month_key)
      values (p_environment_id, v_user.user_id, 'user', v_month_key)
      returning * into v_user_streak;
    end if;

    if v_user_streak.freezes_month_key is distinct from v_month_key then
      v_freezes_left := 2;
      v_month_resets := v_month_resets ||
        jsonb_build_object(v_user.user_id::text, true);
    else
      v_freezes_left := v_user_streak.freezes_left_month;
    end if;

    select count(*) into v_expected_count
      from public.tasks t
     where t.environment_id = p_environment_id
       and t.archived_at is null
       and t.assignee_id = v_user.user_id
       and t.start_date <= v_day
       and (
         t.recurrence_rule is null
         or t.recurrence_rule = ''
         or (
           t.recurrence_rule ~ '^RRULE:FREQ=DAILY;INTERVAL=\d+$'
           and (v_day - t.start_date) %
               (substring(t.recurrence_rule from 'INTERVAL=(\d+)')::int) = 0
         )
       );

    select count(distinct tc.task_id) into v_completed_count
      from public.task_completions tc
      join public.tasks t on t.id = tc.task_id
     where tc.environment_id = p_environment_id
       and tc.completed_by = v_user.user_id
       and (tc.completed_at at time zone v_tz)::date = v_day
       and t.assignee_id = v_user.user_id
       and t.start_date <= v_day;

    if v_expected_count = 0 or v_completed_count >= v_expected_count then
      v_current := v_user_streak.current_count + 1;
      v_best := greatest(v_user_streak.best_count, v_current);
      update public.streaks
         set current_count = v_current,
             best_count = v_best,
             last_evaluated_at = now(),
             freezes_left_month = v_freezes_left,
             freezes_month_key = v_month_key
       where id = v_user_streak.id;
      v_user_outcomes := v_user_outcomes ||
        jsonb_build_object(v_user.user_id::text, 'kept');
    else
      v_any_user_missed := true;
      if v_freezes_left > 0 then
        update public.streaks
           set last_evaluated_at = now(),
               freezes_left_month = v_freezes_left - 1,
               freezes_month_key = v_month_key
         where id = v_user_streak.id;
        v_user_outcomes := v_user_outcomes ||
          jsonb_build_object(v_user.user_id::text, 'frozen');
      else
        -- Streak individual quebrou. Enfileira notif só para este user
        -- (broadcast do ninho cai em outro evento abaixo).
        update public.streaks
           set current_count = 0,
               last_evaluated_at = now(),
               last_failed_at = now(),
               freezes_left_month = v_freezes_left,
               freezes_month_key = v_month_key
         where id = v_user_streak.id;
        v_user_outcomes := v_user_outcomes ||
          jsonb_build_object(v_user.user_id::text, 'broken');
        v_broken_users := v_broken_users || v_user.user_id;
      end if;
    end if;
  end loop;

  if v_any_user_missed then
    update public.streaks
       set current_count = 0,
           last_evaluated_at = now(),
           last_failed_at = now(),
           freezes_left_month = case
             when freezes_month_key is distinct from v_month_key then 2
             else freezes_left_month
           end,
           freezes_month_key = v_month_key
     where id = v_env_streak.id;
    v_env_outcome := 'broken';
  else
    update public.streaks
       set current_count = v_env_streak.current_count + 1,
           best_count = greatest(
             v_env_streak.best_count,
             v_env_streak.current_count + 1
           ),
           last_evaluated_at = now(),
           freezes_left_month = case
             when freezes_month_key is distinct from v_month_key then 2
             else freezes_left_month
           end,
           freezes_month_key = v_month_key
     where id = v_env_streak.id;
    v_env_outcome := 'kept';
  end if;

  -- ============================================================
  -- Fase 7.5: dispara notifs após updates atômicos.
  -- ============================================================
  if array_length(v_broken_users, 1) > 0 then
    perform public.dispatch_notify_event(
      p_environment_id,
      'streak_broken',
      v_broken_users,
      jsonb_build_object('kind', 'user')
    );
  end if;

  if v_env_outcome = 'broken' and v_env_streak.current_count > 0 then
    -- Só notifica se realmente havia streak ativo antes (evita spam de
    -- ninhos zerados que continuam zerando todo dia).
    perform public.dispatch_notify_event(
      p_environment_id,
      'streak_broken',
      null,
      jsonb_build_object('kind', 'environment')
    );
  end if;

  return jsonb_build_object(
    'environment_id', p_environment_id,
    'evaluated_day', v_day,
    'paused', false,
    'users_processed', v_users_processed,
    'user_outcomes', v_user_outcomes,
    'environment_outcome', v_env_outcome,
    'month_resets', v_month_resets,
    'broken_users', to_jsonb(v_broken_users)
  );
end;
$$;
