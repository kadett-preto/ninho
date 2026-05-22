-- Ninho — Fase 7 / RPC evaluate_environment_streaks (IDEA.md §5.7).
--
-- Implementa a engine de streak no servidor — espelha lib/domain/streak_engine.dart
-- mas em PL/pgSQL para uso pelo cron/Edge Function.
--
-- Avalia 1 dia (default: ontem no fuso do ninho). Idempotente quando
-- chamada com o mesmo dia: a query reescreve o estado baseando-se em
-- last_evaluated_at + last_failed_at, mas o conjunto de completions do
-- dia é fixo, então não há drift.

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
  v_task record;
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

  -- Vacation: existe período aberto cobrindo v_day OU iniciado antes/igual
  -- e ainda não encerrado.
  select exists (
    select 1 from public.vacation_periods
     where environment_id = p_environment_id
       and started_on <= v_day
       and (ended_on is null or ended_on >= v_day)
  ) into v_vacation;

  -- Garante linha de streak do ninho.
  select * into v_env_streak
    from public.streaks
   where environment_id = p_environment_id and kind = 'environment';
  if not found then
    insert into public.streaks (environment_id, user_id, kind, freezes_month_key)
    values (p_environment_id, null, 'environment', v_month_key)
    returning * into v_env_streak;
  end if;

  if v_vacation then
    -- Pausa todos os streaks. Apenas atualiza last_evaluated_at + resets
    -- mensais. Não toca em current_count nem freezes.
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

  -- Avalia cada morador ativo.
  for v_user in
    select user_id
      from public.environment_members
     where environment_id = p_environment_id and left_at is null
  loop
    v_users_processed := v_users_processed + 1;

    -- Garante linha de streak do usuário.
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

    -- Reset mensal se virou.
    if v_user_streak.freezes_month_key is distinct from v_month_key then
      v_freezes_left := 2;
      v_month_resets := v_month_resets ||
        jsonb_build_object(v_user.user_id::text, true);
    else
      v_freezes_left := v_user_streak.freezes_left_month;
    end if;

    -- Tasks esperadas: ativa no dia (RRULE FREQ=DAILY;INTERVAL=N) e
    -- atribuída ao usuário. Esquema simples: tasks sem recurrence_rule são
    -- tratadas como diárias após start_date.
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

    -- Completions no dia (todas as tasks deste usuário concluídas por ele).
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
        update public.streaks
           set current_count = 0,
               last_evaluated_at = now(),
               last_failed_at = now(),
               freezes_left_month = v_freezes_left,
               freezes_month_key = v_month_key
         where id = v_user_streak.id;
        v_user_outcomes := v_user_outcomes ||
          jsonb_build_object(v_user.user_id::text, 'broken');
      end if;
    end if;
  end loop;

  -- Streak de ninho: qualquer falha (mesmo coberta por freeze individual)
  -- zera. Freezes do streak de ninho não existem.
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

  return jsonb_build_object(
    'environment_id', p_environment_id,
    'evaluated_day', v_day,
    'paused', false,
    'users_processed', v_users_processed,
    'user_outcomes', v_user_outcomes,
    'environment_outcome', v_env_outcome,
    'month_resets', v_month_resets
  );
end;
$$;

revoke all on function public.evaluate_environment_streaks(uuid, date)
  from public, anon, authenticated;
-- service_role já tem acesso por bypass de RLS. Cron usa service_role.

-- ============================================================
-- Cron schedule via pg_cron (Supabase nativo via extensions schema).
-- Roda a cada hora, evaluates ninhos cujo "agora local" acabou de virar
-- meia-noite. MVP: tolerância de até 60min.
-- ============================================================

create extension if not exists pg_cron with schema extensions;

create or replace function public.run_nightly_streak_evaluation()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_env record;
  v_local_hour integer;
begin
  for v_env in
    select id, timezone from public.environments where archived_at is null
  loop
    v_local_hour := extract(hour from (now() at time zone v_env.timezone))::int;
    -- Roda na primeira hora após meia-noite local (0–0:59).
    if v_local_hour = 0 then
      perform public.evaluate_environment_streaks(v_env.id, null);
    end if;
  end loop;
end;
$$;

revoke all on function public.run_nightly_streak_evaluation()
  from public, anon, authenticated;

-- Schedule. Idempotente — usar nome único e dropar antes.
do $$
begin
  if exists (
    select 1 from cron.job where jobname = 'ninho_streak_nightly'
  ) then
    perform cron.unschedule('ninho_streak_nightly');
  end if;
  perform cron.schedule(
    'ninho_streak_nightly',
    '0 * * * *',
    $body$select public.run_nightly_streak_evaluation()$body$
  );
exception
  -- Ambiente local pode não ter pg_cron acessível para este role; o
  -- schedule entra em produção via service_role.
  when insufficient_privilege then null;
  when undefined_table then null;
  when undefined_function then null;
end;
$$;
