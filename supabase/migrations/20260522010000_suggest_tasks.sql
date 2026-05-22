-- Ninho — Fase 5: RPCs para sugestões de tarefas via IA.
-- IDEA.md §6.3 (IA), §7.6 (rate limit + prompt injection), §5.4 (tasks).
--
-- Dois RPCs SECURITY DEFINER:
--   * `claim_suggest_attempt` — rate-limit por usuário/ninho (audit_log)
--     e autoriza owner antes de invocar Claude na Edge Function.
--   * `accept_suggested_tasks` — insere em public.tasks transacionalmente
--     depois que owner revisa/aceita sugestões no cliente.
--
-- Ambos validam ownership via is_environment_owner() e gravam audit_log.

-- ============================================================
-- claim_suggest_attempt
-- ============================================================
-- Aplicado ANTES da chamada à Claude API. Atomicidade:
--   1. Valida owner.
--   2. Conta tentativas recentes via audit_log (24h).
--   3. Falha cedo se acima do limite (sem gastar token de IA).
--   4. Caso passe, grava 'ai.suggest_attempt' para a próxima requisição
--      enxergar este uso.
-- Limites default: 5/dia/usuário, 10/dia/ninho.
create or replace function public.claim_suggest_attempt(
  p_environment_id uuid,
  p_max_per_user_daily integer default 5,
  p_max_per_env_daily integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_user_count integer;
  v_env_count integer;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  if p_environment_id is null then
    raise exception 'environment_id obrigatório' using errcode = '22023';
  end if;

  if not public.is_environment_owner(p_environment_id) then
    raise exception 'Apenas o owner pode pedir sugestões' using errcode = '42501';
  end if;

  select count(*)::int into v_user_count
    from public.audit_log
   where actor_id = v_user_id
     and action = 'ai.suggest_attempt'
     and created_at > now() - interval '1 day';

  if v_user_count >= p_max_per_user_daily then
    raise exception 'Limite diário do usuário atingido' using errcode = '54000';
  end if;

  select count(*)::int into v_env_count
    from public.audit_log
   where environment_id = p_environment_id
     and action = 'ai.suggest_attempt'
     and created_at > now() - interval '1 day';

  if v_env_count >= p_max_per_env_daily then
    raise exception 'Limite diário do ninho atingido' using errcode = '54000';
  end if;

  insert into public.audit_log
    (environment_id, actor_id, action, target_type)
  values
    (p_environment_id, v_user_id, 'ai.suggest_attempt', 'environment');

  return jsonb_build_object(
    'user_remaining', p_max_per_user_daily - v_user_count - 1,
    'env_remaining', p_max_per_env_daily - v_env_count - 1
  );
end;
$$;

revoke all on function public.claim_suggest_attempt(uuid, integer, integer)
  from public, anon;
grant execute on function public.claim_suggest_attempt(uuid, integer, integer)
  to authenticated;

-- ============================================================
-- accept_suggested_tasks
-- ============================================================
-- Recebe array JSON de sugestões já revisadas/editadas pelo owner e
-- materializa em public.tasks numa transação. Owner-only. Valida tudo
-- defensivamente porque o JSON veio de input do cliente.
--
-- Recurrence_rule: traduzimos interval_days (1/3/7/14/30) para RRULE
-- compatível com iCal — FREQ=DAILY;INTERVAL=N. Engine de streak/jobs
-- da Fase 7 consumirá isso.
create or replace function public.accept_suggested_tasks(
  p_environment_id uuid,
  p_tasks jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_task jsonb;
  v_inserted_ids uuid[] := array[]::uuid[];
  v_task_id uuid;
  v_room_id uuid;
  v_title text;
  v_description text;
  v_difficulty_text text;
  v_difficulty public.task_difficulty;
  v_interval integer;
  v_rrule text;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  if p_environment_id is null then
    raise exception 'environment_id obrigatório' using errcode = '22023';
  end if;

  if not public.is_environment_owner(p_environment_id) then
    raise exception 'Apenas o owner pode aceitar sugestões' using errcode = '42501';
  end if;

  if p_tasks is null or jsonb_typeof(p_tasks) <> 'array' then
    raise exception 'Lista de tasks inválida' using errcode = '22023';
  end if;

  if jsonb_array_length(p_tasks) = 0 or jsonb_array_length(p_tasks) > 50 then
    raise exception 'Informe entre 1 e 50 tarefas' using errcode = '22023';
  end if;

  for v_task in select * from jsonb_array_elements(p_tasks) loop
    v_room_id := nullif(v_task->>'room_id', '')::uuid;
    v_title := trim(coalesce(v_task->>'title', ''));
    v_description := nullif(trim(coalesce(v_task->>'description', '')), '');
    v_difficulty_text := lower(coalesce(v_task->>'difficulty', ''));
    v_interval := nullif(v_task->>'interval_days', '')::integer;

    if v_title = '' or char_length(v_title) > 120 then
      raise exception 'Título inválido' using errcode = '22023';
    end if;

    if v_difficulty_text not in ('mamao', 'embacada', 'treta') then
      raise exception 'Dificuldade inválida' using errcode = '22023';
    end if;
    v_difficulty := v_difficulty_text::public.task_difficulty;

    if v_interval is null or v_interval not in (1, 3, 7, 14, 30) then
      raise exception 'Recorrência inválida' using errcode = '22023';
    end if;

    -- room_id é opcional, mas se vier precisa pertencer ao ninho.
    -- Pega cliente que tenta atribuir tarefa a cômodo de outro ninho.
    if v_room_id is not null and not exists (
      select 1 from public.rooms
       where id = v_room_id and environment_id = p_environment_id
    ) then
      raise exception 'Cômodo não pertence ao ninho' using errcode = '23503';
    end if;

    v_rrule := 'FREQ=DAILY;INTERVAL=' || v_interval::text;

    insert into public.tasks (
      environment_id, room_id, title, description,
      difficulty, start_date, recurrence_rule, created_by
    ) values (
      p_environment_id, v_room_id, v_title, v_description,
      v_difficulty, current_date, v_rrule, v_user_id
    )
    returning id into v_task_id;

    v_inserted_ids := array_append(v_inserted_ids, v_task_id);
  end loop;

  insert into public.audit_log
    (environment_id, actor_id, action, target_type, metadata)
  values
    (p_environment_id, v_user_id, 'ai.suggest_accept', 'task',
     jsonb_build_object('count', array_length(v_inserted_ids, 1)));

  return jsonb_build_object(
    'inserted_count', array_length(v_inserted_ids, 1),
    'task_ids', to_jsonb(v_inserted_ids)
  );
end;
$$;

revoke all on function public.accept_suggested_tasks(uuid, jsonb)
  from public, anon;
grant execute on function public.accept_suggested_tasks(uuid, jsonb)
  to authenticated;
