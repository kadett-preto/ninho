-- Ninho — Fase 7 / Modo viagem (IDEA.md §5.7 + §5.7 último item).
-- Owner pode pausar o ninho até 14d/ano. Dias dentro de uma vacation_period
-- são ignorados pelo evaluator de streaks.

create table public.vacation_periods (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  started_on date not null,
  ended_on date,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  -- Apenas 1 período aberto por ninho.
  constraint vacation_periods_dates_valid check (
    ended_on is null or ended_on >= started_on
  )
);

create unique index vacation_periods_one_open_per_env
  on public.vacation_periods (environment_id)
  where ended_on is null;

create index vacation_periods_env_idx
  on public.vacation_periods (environment_id, started_on);

alter table public.vacation_periods enable row level security;

create policy vacation_periods_select_member
  on public.vacation_periods for select
  using (public.is_environment_member(environment_id));

-- Sem INSERT/UPDATE/DELETE de cliente — só via RPCs SECURITY DEFINER.

-- ============================================================
-- start_vacation
-- ============================================================
-- Owner-only. Valida que não há período aberto + não estoura 14d/ano.
-- Marca environments.vacation_mode = true em UPDATE atômico.
create or replace function public.start_vacation(p_environment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_today date := (now() at time zone (
    select timezone from public.environments where id = p_environment_id
  ))::date;
  v_used_year integer;
  v_year_start date := date_trunc('year', v_today)::date;
  v_period_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;
  if not public.is_environment_owner(p_environment_id) then
    raise exception 'Apenas o owner pode iniciar modo viagem'
      using errcode = '42501';
  end if;

  if exists (
    select 1 from public.vacation_periods
     where environment_id = p_environment_id and ended_on is null
  ) then
    raise exception 'Ninho já está em modo viagem' using errcode = '22023';
  end if;

  -- Soma dias usados no ano (excluindo períodos abertos — não existem aqui).
  select coalesce(sum(ended_on - started_on + 1), 0)
    into v_used_year
    from public.vacation_periods
   where environment_id = p_environment_id
     and started_on >= v_year_start;

  if v_used_year >= 14 then
    raise exception 'Limite de 14 dias de viagem/ano atingido'
      using errcode = '22023';
  end if;

  insert into public.vacation_periods (environment_id, started_on, created_by)
  values (p_environment_id, v_today, v_user_id)
  returning id into v_period_id;

  update public.environments
     set vacation_mode = true
   where id = p_environment_id;

  return jsonb_build_object(
    'period_id', v_period_id,
    'started_on', v_today,
    'days_used_year', v_used_year
  );
end;
$$;

revoke all on function public.start_vacation(uuid) from public, anon;
grant execute on function public.start_vacation(uuid) to authenticated;

-- ============================================================
-- end_vacation
-- ============================================================
create or replace function public.end_vacation(p_environment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_today date := (now() at time zone (
    select timezone from public.environments where id = p_environment_id
  ))::date;
  v_period_id uuid;
  v_started_on date;
  v_days integer;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;
  if not public.is_environment_owner(p_environment_id) then
    raise exception 'Apenas o owner pode encerrar modo viagem'
      using errcode = '42501';
  end if;

  update public.vacation_periods
     set ended_on = v_today
   where environment_id = p_environment_id and ended_on is null
  returning id, started_on into v_period_id, v_started_on;

  if v_period_id is null then
    raise exception 'Ninho não está em modo viagem' using errcode = '22023';
  end if;

  update public.environments
     set vacation_mode = false,
         vacation_days_used_year =
           coalesce(vacation_days_used_year, 0) + (v_today - v_started_on + 1)
   where id = p_environment_id;

  v_days := v_today - v_started_on + 1;
  return jsonb_build_object(
    'period_id', v_period_id,
    'ended_on', v_today,
    'days', v_days
  );
end;
$$;

revoke all on function public.end_vacation(uuid) from public, anon;
grant execute on function public.end_vacation(uuid) to authenticated;
