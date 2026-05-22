-- Ninho — Fase 10.5: resumo semanal por IA publicado no mural.
--
-- Componentes:
--   * RPC `publish_weekly_summary` (SECURITY DEFINER, service_role only)
--     — insere feed_event `weekly.summary` + audit_log. Centraliza a
--     escrita pra qualquer caller futuro (Edge Function ou backfill).
--   * Função `run_weekly_summary_dispatch` invoca Edge Function via
--     pg_net (mesmo padrão de `run_send_task_reminders`).
--   * Cron horário: dispara a função; a Edge Function filtra ninhos cujo
--     "agora local" bate com domingo 20:00 ± 30min e dedup por janela
--     de 6 dias.

create extension if not exists pg_net with schema extensions;

-- ============================================================
-- RPC publish_weekly_summary
-- ============================================================
-- Insere o evento de resumo no mural, com payload estruturado.
-- Não revalida idempotência aqui — a Edge Function dedupa antes
-- (lock advisory via cron + checagem de feed_events). Mantém o RPC
-- enxuto e auditável.

create or replace function public.publish_weekly_summary(
  p_environment_id uuid,
  p_summary text,
  p_task_count integer,
  p_photo_count integer,
  p_range_start date,
  p_range_end date,
  p_model text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_id uuid;
  v_summary text := nullif(btrim(coalesce(p_summary, '')), '');
begin
  if p_environment_id is null then
    raise exception 'environment_id obrigatório' using errcode = '22023';
  end if;

  if v_summary is null then
    raise exception 'summary vazio' using errcode = '22023';
  end if;

  if char_length(v_summary) > 600 then
    raise exception 'summary muito longo' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.environments where id = p_environment_id
  ) then
    raise exception 'Ninho inexistente' using errcode = '42704';
  end if;

  insert into public.feed_events (
    environment_id,
    actor_id,
    event_type,
    payload
  )
  values (
    p_environment_id,
    null, -- system event
    'weekly.summary',
    jsonb_build_object(
      'summary', v_summary,
      'task_count', coalesce(p_task_count, 0),
      'photo_count', coalesce(p_photo_count, 0),
      'range_start', p_range_start,
      'range_end', p_range_end,
      'model', p_model
    )
  )
  returning id into v_event_id;

  insert into public.audit_log (
    environment_id,
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  )
  values (
    p_environment_id,
    null,
    'feed.weekly_summary',
    'feed_event',
    v_event_id,
    jsonb_build_object(
      'task_count', coalesce(p_task_count, 0),
      'photo_count', coalesce(p_photo_count, 0),
      'range_start', p_range_start,
      'range_end', p_range_end,
      'model', p_model
    )
  );

  return jsonb_build_object('event_id', v_event_id);
end;
$$;

-- Cliente nunca chama; apenas service_role (Edge Function).
revoke all on function public.publish_weekly_summary(
  uuid, text, integer, integer, date, date, text
) from public, anon, authenticated;

-- ============================================================
-- Cron dispatch
-- ============================================================
-- Padrão idêntico a run_send_task_reminders. A Edge Function decide
-- quais ninhos publicam neste tick (filtro de timezone + dedup).

create or replace function public.run_weekly_summary_dispatch()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_service_role text;
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

  perform extensions.http_post(
    url := v_url || '/functions/v1/weekly-summary',
    headers := jsonb_build_object(
      'authorization', 'Bearer ' || v_service_role,
      'content-type', 'application/json'
    ),
    body := jsonb_build_object('trigger', 'cron'),
    timeout_milliseconds := 60000
  );
exception
  when undefined_function then null;
  when undefined_table then null;
  when insufficient_privilege then null;
  when others then
    null;
end;
$$;

revoke all on function public.run_weekly_summary_dispatch()
  from public, anon, authenticated;

do $$
begin
  if exists (
    select 1 from cron.job where jobname = 'ninho_weekly_summary_hourly'
  ) then
    perform cron.unschedule('ninho_weekly_summary_hourly');
  end if;
  -- Hora cheia, todo dia. A Edge Function filtra para domingo 20:00
  -- local com tolerância de 30min em cada fuso de ninho.
  perform cron.schedule(
    'ninho_weekly_summary_hourly',
    '0 * * * *',
    $body$select public.run_weekly_summary_dispatch()$body$
  );
exception
  when insufficient_privilege then null;
  when undefined_table then null;
  when undefined_function then null;
end;
$$;
