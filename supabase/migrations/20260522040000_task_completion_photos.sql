-- Ninho — Fase 6.6: fotos opcionais de conclusão de task.
-- IDEA.md §5.4, §5.9, §7.4.
--
-- Bucket privado separado das fotos de cômodo. O path canônico é:
--   {environment_id}/task-completions/{task_id}/{arquivo}.jpg
-- A RPC `complete_task` só aceita `photo_path` existente nesse bucket e no
-- prefixo da task concluída.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'task-completion-photos',
  'task-completion-photos',
  false,
  8388608,
  array['image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists task_completion_photos_select_member on storage.objects;
create policy task_completion_photos_select_member
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'task-completion-photos'
    and public.is_environment_member(public.storage_object_environment_id(name))
  );

drop policy if exists task_completion_photos_insert_member on storage.objects;
create policy task_completion_photos_insert_member
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'task-completion-photos'
    and lower(name) like '%.jpg'
    and (storage.foldername(name))[2] = 'task-completions'
    and public.is_environment_member(public.storage_object_environment_id(name))
  );

create or replace function public.complete_task(
  p_task_id uuid,
  p_photo_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_task record;
  v_existing_completion record;
  v_completion_id uuid;
  v_feed_event_id uuid;
  v_reward_delta integer;
  v_suppressed_count integer := 0;
  v_photo_path text := nullif(btrim(coalesce(p_photo_path, '')), '');
  v_photo_prefix text;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  if p_task_id is null then
    raise exception 'Task inválida' using errcode = '22023';
  end if;

  select
    t.id,
    t.environment_id,
    t.room_id,
    t.title,
    t.difficulty,
    t.assignee_id,
    t.archived_at,
    public.is_environment_owner(t.environment_id) as is_owner
  into v_task
  from public.tasks t
  where t.id = p_task_id
  for update;

  if v_task.id is null then
    raise exception 'Task não encontrada' using errcode = '42704';
  end if;

  if v_task.archived_at is not null then
    raise exception 'Task arquivada' using errcode = '22023';
  end if;

  if not public.is_environment_member(v_task.environment_id) then
    raise exception 'Task não encontrada' using errcode = '42704';
  end if;

  if not (
    v_task.is_owner
    or v_task.assignee_id is null
    or v_task.assignee_id = v_user_id
  ) then
    raise exception 'Apenas o responsável pode concluir esta task' using errcode = '42501';
  end if;

  if v_photo_path is not null then
    v_photo_prefix := v_task.environment_id::text
      || '/task-completions/'
      || v_task.id::text
      || '/';

    if position(v_photo_prefix in v_photo_path) <> 1
      or lower(v_photo_path) not like '%.jpg'
      or public.storage_object_environment_id(v_photo_path) is distinct from v_task.environment_id
      or not exists (
        select 1
          from storage.objects o
         where o.bucket_id = 'task-completion-photos'
           and o.name = v_photo_path
      )
    then
      raise exception 'Foto de conclusão inválida' using errcode = '22023';
    end if;
  end if;

  select id
    into v_existing_completion
    from public.task_completions
   where task_id = v_task.id
     and environment_id = v_task.environment_id
     and completed_at >= date_trunc('day', now())
     and completed_at < date_trunc('day', now()) + interval '1 day'
   order by completed_at asc
   limit 1;

  if v_existing_completion.id is not null then
    update public.notification_log
       set suppressed_reason = 'task_completed'
     where environment_id = v_task.environment_id
       and task_id = v_task.id
       and sent_at is null
       and suppressed_reason is null
       and scheduled_for >= now();

    get diagnostics v_suppressed_count = row_count;

    return jsonb_build_object(
      'completion_id', v_existing_completion.id,
      'already_completed', true,
      'reward_delta', 0,
      'notification_suppressed_count', v_suppressed_count,
      'feed_event_id', null
    );
  end if;

  v_reward_delta := case v_task.difficulty
    when 'mamao'::public.task_difficulty then 5
    when 'embacada'::public.task_difficulty then 15
    when 'treta'::public.task_difficulty then 40
  end;

  insert into public.task_completions (
    task_id,
    environment_id,
    completed_by,
    photo_path
  )
  values (
    v_task.id,
    v_task.environment_id,
    v_user_id,
    v_photo_path
  )
  returning id into v_completion_id;

  insert into public.dust_ledger (
    environment_id,
    user_id,
    delta,
    reason,
    related_task_id,
    related_completion_id
  )
  values (
    v_task.environment_id,
    v_user_id,
    v_reward_delta,
    'task_completed',
    v_task.id,
    v_completion_id
  );

  update public.notification_log
     set suppressed_reason = 'task_completed'
   where environment_id = v_task.environment_id
     and task_id = v_task.id
     and sent_at is null
     and suppressed_reason is null
     and scheduled_for >= now();

  get diagnostics v_suppressed_count = row_count;

  insert into public.feed_events (
    environment_id,
    actor_id,
    event_type,
    payload
  )
  values (
    v_task.environment_id,
    v_user_id,
    'task.completed',
    jsonb_build_object(
      'task_id', v_task.id,
      'task_title', v_task.title,
      'room_id', v_task.room_id,
      'difficulty', v_task.difficulty,
      'reward_delta', v_reward_delta,
      'completion_id', v_completion_id,
      'photo_path', v_photo_path
    )
  )
  returning id into v_feed_event_id;

  insert into public.audit_log (
    environment_id,
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  )
  values (
    v_task.environment_id,
    v_user_id,
    'task.complete',
    'task',
    v_task.id,
    jsonb_build_object(
      'completion_id', v_completion_id,
      'reward_delta', v_reward_delta,
      'notification_suppressed_count', v_suppressed_count,
      'photo_attached', v_photo_path is not null
    )
  );

  return jsonb_build_object(
    'completion_id', v_completion_id,
    'already_completed', false,
    'reward_delta', v_reward_delta,
    'notification_suppressed_count', v_suppressed_count,
    'feed_event_id', v_feed_event_id
  );
end;
$$;

revoke all on function public.complete_task(uuid, text) from public, anon;
grant execute on function public.complete_task(uuid, text) to authenticated;
