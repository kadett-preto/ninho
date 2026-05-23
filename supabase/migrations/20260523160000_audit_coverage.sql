-- Ninho — Fase 11.9 / IDEA.md §7.5: audit log completo de ações
-- sensíveis. Cobre buracos não auditados das fases anteriores:
--
--   * `start_vacation` / `end_vacation` (Fase 7.4) — agora gravam audit.
--   * `set_transfer_item_enabled` (Fase 9.5) — agora grava audit.
--   * Mutations diretas em `rooms` (Fase 11.8 CRUD) — trigger
--     after insert/update/delete grava audit.
--   * Mutations diretas em `tasks` (CRUD via PostgREST) — trigger
--     after insert/update grava audit.
--
-- Triggers usam `auth.uid()` para preencher actor, que estará disponível
-- em contextos PostgREST (JWT). Inserts feitos por jobs server-side
-- (sem session) gravam actor=null — auditoria de sistema fica explícita.

-- ============================================================
-- start_vacation (recriar com audit)
-- ============================================================
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
    raise exception 'Modo viagem já está ativo' using errcode = '22023';
  end if;

  select coalesce(sum(
    (coalesce(ended_on, v_today) - started_on + 1)
  ), 0)::int
    into v_used_year
    from public.vacation_periods
   where environment_id = p_environment_id
     and started_on >= v_year_start;

  if v_used_year >= 14 then
    raise exception 'Cota anual de modo viagem atingida (14 dias)'
      using errcode = '22023';
  end if;

  insert into public.vacation_periods (environment_id, started_on, created_by)
  values (p_environment_id, v_today, v_user_id)
  returning id into v_period_id;

  update public.environments
     set vacation_mode = true
   where id = p_environment_id;

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    p_environment_id,
    v_user_id,
    'environment.vacation_started',
    'environment',
    p_environment_id,
    jsonb_build_object(
      'period_id', v_period_id,
      'started_on', v_today,
      'days_used_year', v_used_year
    )
  );

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
-- end_vacation (recriar com audit)
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

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    p_environment_id,
    v_user_id,
    'environment.vacation_ended',
    'environment',
    p_environment_id,
    jsonb_build_object(
      'period_id', v_period_id,
      'started_on', v_started_on,
      'ended_on', v_today,
      'days', v_days
    )
  );

  return jsonb_build_object(
    'period_id', v_period_id,
    'ended_on', v_today,
    'days', v_days
  );
end;
$$;

revoke all on function public.end_vacation(uuid) from public, anon;
grant execute on function public.end_vacation(uuid) to authenticated;

-- ============================================================
-- set_transfer_item_enabled (recriar com audit)
-- ============================================================
create or replace function public.set_transfer_item_enabled(
  p_environment_id uuid,
  p_enabled boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := auth.uid();
begin
  if v_caller is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;
  if not public.is_environment_owner(p_environment_id) then
    raise exception 'Apenas o owner pode mudar a loja' using errcode = '42501';
  end if;
  update public.environments
     set transfer_item_enabled = p_enabled
   where id = p_environment_id;

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    p_environment_id,
    v_caller,
    'shop.transfer_item_toggled',
    'environment',
    p_environment_id,
    jsonb_build_object('enabled', p_enabled)
  );

  return p_enabled;
end;
$$;

revoke all on function public.set_transfer_item_enabled(uuid, boolean)
  from public, anon;
grant execute on function public.set_transfer_item_enabled(uuid, boolean)
  to authenticated;

-- ============================================================
-- Triggers de audit em rooms (insert/update/delete)
-- ============================================================
create or replace function public.audit_rooms_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action text;
  v_env uuid;
  v_target uuid;
  v_meta jsonb;
begin
  if (tg_op = 'INSERT') then
    v_action := 'room.created';
    v_env := new.environment_id;
    v_target := new.id;
    v_meta := jsonb_build_object('name', new.name, 'size', new.size_category);
  elsif (tg_op = 'UPDATE') then
    v_action := 'room.updated';
    v_env := new.environment_id;
    v_target := new.id;
    v_meta := jsonb_build_object(
      'name', new.name,
      'size', new.size_category,
      'name_changed', new.name is distinct from old.name,
      'size_changed', new.size_category is distinct from old.size_category,
      'photo_changed', new.photo_path is distinct from old.photo_path
    );
  else
    v_action := 'room.deleted';
    v_env := old.environment_id;
    v_target := old.id;
    v_meta := jsonb_build_object('name', old.name);
  end if;

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    v_env,
    auth.uid(),
    v_action,
    'room',
    v_target,
    v_meta
  );

  if (tg_op = 'DELETE') then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists rooms_audit_trigger on public.rooms;
create trigger rooms_audit_trigger
after insert or update or delete on public.rooms
for each row execute function public.audit_rooms_change();

-- ============================================================
-- Triggers de audit em tasks (insert/update — soft delete via archived_at
-- entra como update)
-- ============================================================
create or replace function public.audit_tasks_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action text;
  v_env uuid;
  v_target uuid;
  v_meta jsonb;
begin
  if (tg_op = 'INSERT') then
    v_action := 'task.created';
    v_env := new.environment_id;
    v_target := new.id;
    v_meta := jsonb_build_object(
      'difficulty', new.difficulty,
      'recurrence', new.recurrence_rule,
      'has_room', new.room_id is not null
    );
  elsif (tg_op = 'UPDATE') then
    if new.archived_at is not null and old.archived_at is null then
      v_action := 'task.archived';
    else
      v_action := 'task.updated';
    end if;
    v_env := new.environment_id;
    v_target := new.id;
    v_meta := jsonb_build_object(
      'difficulty_changed', new.difficulty is distinct from old.difficulty,
      'assignee_changed', new.assignee_id is distinct from old.assignee_id,
      'archived', new.archived_at is not null
    );
  else
    v_action := 'task.deleted';
    v_env := old.environment_id;
    v_target := old.id;
    v_meta := jsonb_build_object('title_hash', md5(coalesce(old.title, '')));
  end if;

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    v_env,
    auth.uid(),
    v_action,
    'task',
    v_target,
    v_meta
  );

  if (tg_op = 'DELETE') then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists tasks_audit_trigger on public.tasks;
create trigger tasks_audit_trigger
after insert or update or delete on public.tasks
for each row execute function public.audit_tasks_change();
