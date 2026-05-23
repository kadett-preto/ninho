-- Ninho — Fase 11.3 + 11.5 / LGPD §5.10 + §5.5: retention jobs.
--
-- Dois cron jobs diários que sustentam as garantias de retenção:
--
--   1. `purge_deleted_accounts()` — para cada `users.deleted_at` com 30+
--      dias, anonimiza o perfil em public.users (display_name => null,
--      locale resetado, lgpd_consent_at zerado, marca purged_at). A
--      deleção definitiva da linha em auth.users fica como handoff para
--      a admin API (não é seguro fazer via SQL puro sem service_role);
--      a anonimização SQL já satisfaz o requisito LGPD de remover PII
--      no prazo.
--
--   2. `archive_inactive_environments()` — para cada environment sem
--      membros ativos há 30+ dias (último `left_at` ou só esqueleto),
--      preenche `archived_at` e gera audit.
--
-- Ambos rodam como SECURITY DEFINER e estão revogados de
-- public/anon/authenticated; só `service_role` (e pg_cron como dono do
-- DB) podem invocar.

alter table public.users
  add column if not exists purged_at timestamptz;

create or replace function public.purge_deleted_accounts(
  p_retention_days int default 30
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int := 0;
  v_user record;
begin
  for v_user in
    select id
      from public.users
     where deleted_at is not null
       and purged_at is null
       and deleted_at < now() - make_interval(days => p_retention_days)
  loop
    update public.users
       set display_name = null,
           locale = 'pt-BR',
           lgpd_consent_at = null,
           purged_at = now()
     where id = v_user.id;

    insert into public.audit_log (
      environment_id,
      actor_id,
      action,
      target_type,
      target_id,
      metadata
    )
    values (
      null,
      null,
      'user.purged',
      'user',
      v_user.id,
      jsonb_build_object('retention_days', p_retention_days)
    );

    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.purge_deleted_accounts(int)
  from public, anon, authenticated;

create or replace function public.archive_inactive_environments(
  p_grace_days int default 30
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int := 0;
  v_env record;
  v_last_left timestamptz;
begin
  for v_env in
    select e.id
      from public.environments e
     where e.archived_at is null
       and not exists (
         select 1 from public.environment_members em
          where em.environment_id = e.id
            and em.left_at is null
       )
  loop
    -- Considera o membership mais recente que saiu (ou created_at do env
    -- se nunca houve membro ativo).
    select coalesce(
             (select max(em.left_at)
                from public.environment_members em
               where em.environment_id = v_env.id),
             (select created_at
                from public.environments
               where id = v_env.id)
           )
      into v_last_left;

    if v_last_left is null
       or v_last_left >= now() - make_interval(days => p_grace_days) then
      continue;
    end if;

    update public.environments
       set archived_at = now()
     where id = v_env.id;

    insert into public.audit_log (
      environment_id,
      actor_id,
      action,
      target_type,
      target_id,
      metadata
    )
    values (
      v_env.id,
      null,
      'environment.archived_inactive',
      'environment',
      v_env.id,
      jsonb_build_object('grace_days', p_grace_days)
    );

    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.archive_inactive_environments(int)
  from public, anon, authenticated;

create or replace function public.run_retention_jobs()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.purge_deleted_accounts();
  perform public.archive_inactive_environments();
exception
  when others then
    -- Jobs de retenção nunca devem quebrar o cron; logar via audit_log
    -- futuro fica para 11.9.
    null;
end;
$$;

revoke all on function public.run_retention_jobs() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'ninho_retention_daily') then
    perform cron.unschedule('ninho_retention_daily');
  end if;
  perform cron.schedule(
    'ninho_retention_daily',
    '0 3 * * *',
    $body$select public.run_retention_jobs()$body$
  );
exception
  when insufficient_privilege then null;
  when undefined_table then null;
  when undefined_function then null;
end;
$$;
