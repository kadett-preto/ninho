-- Ninho — Fase 8.4: cron horário (a cada 15min) dispara
-- Edge Function send-task-reminders. A função decide quem está nos slots
-- 09h/15h/20h locais. Mantém a cota de chamadas baixa.
--
-- Em produção, o secret SERVICE_ROLE_KEY já está disponível via
-- supabase.co; em dev local pode rodar como noop se a função não estiver
-- servida.

create extension if not exists pg_net with schema extensions;

create or replace function public.run_send_task_reminders()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_service_role text;
begin
  -- supabase_url e service_role ficam acessíveis via current_setting em
  -- ambiente managed. Em local, fallback para localhost.
  v_url := coalesce(
    current_setting('app.settings.supabase_url', true),
    'http://kong:8000'
  );
  v_service_role := coalesce(
    current_setting('app.settings.service_role_key', true),
    ''
  );

  if v_service_role = '' then
    -- Nada a fazer sem o secret (ambiente local). Não-op silencioso.
    return;
  end if;

  perform extensions.http_post(
    url := v_url || '/functions/v1/send-task-reminders',
    headers := jsonb_build_object(
      'authorization', 'Bearer ' || v_service_role,
      'content-type', 'application/json'
    ),
    body := jsonb_build_object('trigger', 'cron'),
    timeout_milliseconds := 30000
  );
exception
  when undefined_function then null;
  when undefined_table then null;
  when insufficient_privilege then null;
  when others then
    -- Cron não deve quebrar se o HTTP falhou.
    null;
end;
$$;

revoke all on function public.run_send_task_reminders()
  from public, anon, authenticated;

do $$
begin
  if exists (
    select 1 from cron.job where jobname = 'ninho_reminders_15min'
  ) then
    perform cron.unschedule('ninho_reminders_15min');
  end if;
  perform cron.schedule(
    'ninho_reminders_15min',
    '*/15 * * * *',
    $body$select public.run_send_task_reminders()$body$
  );
exception
  when insufficient_privilege then null;
  when undefined_table then null;
  when undefined_function then null;
end;
$$;
