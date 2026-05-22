-- Ninho — Fase 9: loja + transferência de task (IDEA.md §5.8).
--
-- Regras (IDEA.md §5.8):
--   - Custo: 30 poeiras (configurável via const TRANSFER_COST).
--   - Limite: 1 transferência por semana ISO por usuário.
--   - Owner pode desligar o item via environments.transfer_item_enabled.
--   - Destinatário não pode recusar.
--   - Antiabuso: não pode transferir para o mesmo destinatário em duas
--     semanas consecutivas (em MVP 2-pessoas vira cooldown extra de 1
--     semana após cada uso).
--   - Quem conclui ganha a poeira (não quem transferiu).

-- ============================================================
-- get_dust_balance — saldo do auth.uid() no ninho
-- ============================================================

create or replace function public.get_dust_balance(p_environment_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(delta), 0)::int
    from public.dust_ledger
   where environment_id = p_environment_id
     and user_id = auth.uid();
$$;

revoke all on function public.get_dust_balance(uuid) from public, anon;
grant execute on function public.get_dust_balance(uuid) to authenticated;

-- ============================================================
-- transfer_task — atômico
-- ============================================================

create or replace function public.transfer_task(
  p_task_id uuid,
  p_to_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := auth.uid();
  v_task public.tasks%rowtype;
  v_env public.environments%rowtype;
  v_balance integer;
  v_iso_week text;
  v_last_to uuid;
  v_member_count integer;
  v_cost constant integer := 30;
  v_transfer_id uuid;
begin
  if v_caller is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  -- Task + ownership check.
  select * into v_task from public.tasks where id = p_task_id;
  if not found then
    raise exception 'Tarefa não encontrada' using errcode = '42704';
  end if;

  select * into v_env from public.environments where id = v_task.environment_id;
  if not found then
    raise exception 'Ninho não encontrado' using errcode = '42704';
  end if;

  if not v_env.transfer_item_enabled then
    raise exception 'Transferência desativada neste ninho'
      using errcode = '22023';
  end if;

  if not public.is_environment_member(v_task.environment_id) then
    raise exception 'Sem permissão para esta tarefa'
      using errcode = '42501';
  end if;

  if v_task.archived_at is not null then
    raise exception 'Tarefa arquivada' using errcode = '22023';
  end if;

  if v_task.assignee_id is null or v_task.assignee_id <> v_caller then
    raise exception 'Você só transfere as próprias tarefas'
      using errcode = '42501';
  end if;

  if p_to_user_id = v_caller then
    raise exception 'Destinatário inválido (não pode ser você mesmo)'
      using errcode = '22023';
  end if;

  -- Destinatário tem que ser membro ativo do mesmo ninho.
  if not exists (
    select 1 from public.environment_members
     where environment_id = v_task.environment_id
       and user_id = p_to_user_id
       and left_at is null
  ) then
    raise exception 'Destinatário não está neste ninho'
      using errcode = '42501';
  end if;

  -- Saldo suficiente.
  select coalesce(sum(delta), 0)::int into v_balance
    from public.dust_ledger
   where environment_id = v_task.environment_id and user_id = v_caller;
  if v_balance < v_cost then
    raise exception 'Saldo insuficiente (precisa de % poeiras)', v_cost
      using errcode = '22023';
  end if;

  -- Limite de 1/semana ISO.
  v_iso_week := to_char(now(), 'IYYY-IW');
  if exists (
    select 1 from public.task_transfers
     where environment_id = v_task.environment_id
       and from_user_id = v_caller
       and iso_year_week = v_iso_week
  ) then
    raise exception 'Você já usou sua transferência desta semana'
      using errcode = '22023';
  end if;

  -- Antiabuso: destinatário consecutivo. Para MVP 2-pessoas, isso vira
  -- cooldown extra (única opção de destino é a outra pessoa, então
  -- bloqueia 1 semana após qualquer uso).
  select to_user_id into v_last_to
    from public.task_transfers
   where environment_id = v_task.environment_id
     and from_user_id = v_caller
   order by created_at desc
   limit 1;

  select count(*) into v_member_count
    from public.environment_members
   where environment_id = v_task.environment_id and left_at is null;

  if v_last_to is not null then
    -- Calcula semana ISO da última transferência.
    if exists (
      select 1 from public.task_transfers
       where environment_id = v_task.environment_id
         and from_user_id = v_caller
         and to_user_id = v_last_to
         and iso_year_week = to_char(now() - interval '1 week', 'IYYY-IW')
    ) and v_last_to = p_to_user_id then
      raise exception 'Não pode transferir para o mesmo destinatário em semanas consecutivas'
        using errcode = '22023';
    end if;
    -- MVP 2-pessoas: cooldown extra. Só destinatário possível é o último.
    if v_member_count <= 2 and v_last_to = p_to_user_id and exists (
      select 1 from public.task_transfers
       where environment_id = v_task.environment_id
         and from_user_id = v_caller
         and to_user_id = v_last_to
         and iso_year_week = to_char(now() - interval '1 week', 'IYYY-IW')
    ) then
      raise exception 'Cooldown extra (2-pessoas): aguarde mais uma semana'
        using errcode = '22023';
    end if;
  end if;

  -- Tudo ok. Debita poeira, reassigna task, registra transfer + audit.
  insert into public.dust_ledger (
    environment_id, user_id, delta, reason, related_task_id
  ) values (
    v_task.environment_id, v_caller, -v_cost, 'shop_transfer', p_task_id
  );

  update public.tasks
     set assignee_id = p_to_user_id,
         updated_at = now()
   where id = p_task_id;

  insert into public.task_transfers (
    environment_id, task_id, from_user_id, to_user_id,
    iso_year_week, cost_dust
  ) values (
    v_task.environment_id, p_task_id, v_caller, p_to_user_id,
    v_iso_week, v_cost
  )
  returning id into v_transfer_id;

  insert into public.audit_log (
    environment_id, actor_id, action, target_type, target_id, metadata
  ) values (
    v_task.environment_id,
    v_caller,
    'shop.task_transfer',
    'task',
    p_task_id,
    jsonb_build_object(
      'to_user', p_to_user_id,
      'cost', v_cost,
      'transfer_id', v_transfer_id
    )
  );

  -- Notif para o destinatário (Fase 8.9).
  perform public.dispatch_notify_event(
    v_task.environment_id,
    'task_transferred',
    array[p_to_user_id],
    jsonb_build_object('task_id', p_task_id, 'from_user', v_caller)
  );

  return jsonb_build_object(
    'transfer_id', v_transfer_id,
    'task_id', p_task_id,
    'to_user_id', p_to_user_id,
    'cost', v_cost,
    'new_balance', v_balance - v_cost
  );
end;
$$;

revoke all on function public.transfer_task(uuid, uuid) from public, anon;
grant execute on function public.transfer_task(uuid, uuid) to authenticated;

-- ============================================================
-- toggle_transfer_item — owner liga/desliga o item da loja
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
  return p_enabled;
end;
$$;

revoke all on function public.set_transfer_item_enabled(uuid, boolean)
  from public, anon;
grant execute on function public.set_transfer_item_enabled(uuid, boolean)
  to authenticated;
