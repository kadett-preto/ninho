-- Ninho — Fase 2 / Task 2.7: persistência LGPD.
-- IDEA.md §3.10, §5.10, §7.5.
--
-- 1. Colunas opt-in/opt-out de notificações e métricas em public.users.
-- 2. Trigger em auth.users (signup) garante 1 linha em public.users.
-- 3. Trigger em public.users (update lgpd_consent_at) emite audit_log
--    "consent.lgpd.accepted" — append-only, ignora RLS via security definer.

-- ============================================================
-- 1. Colunas de consentimento granular
-- ============================================================

alter table public.users
  add column if not exists notifications_consent boolean not null default false,
  add column if not exists analytics_consent boolean not null default false;

-- ============================================================
-- 2. Trigger: auth.users insert -> public.users insert
-- ============================================================
-- Roda como security definer p/ poder inserir em public.users mesmo quando
-- o caller é o role authenticated (que tem RLS aplicada).

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, display_name, locale)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    coalesce(new.raw_user_meta_data->>'locale', 'pt-BR')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- ============================================================
-- 3. Trigger: users update -> audit_log "consent.lgpd.accepted"
-- ============================================================

create or replace function public.log_lgpd_consent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Só dispara quando o campo lgpd_consent_at mudou de NULL para um timestamp
  -- (primeira aceitação). Atualizações subsequentes (re-aceite após mudança
  -- de política) também valem; o critério é OLD distinct from NEW.
  if old.lgpd_consent_at is distinct from new.lgpd_consent_at
     and new.lgpd_consent_at is not null then
    insert into public.audit_log (
      environment_id, actor_id, action, target_type, target_id, metadata
    )
    values (
      null,
      new.id,
      'consent.lgpd.accepted',
      'user',
      new.id,
      jsonb_build_object(
        'notifications_consent', new.notifications_consent,
        'analytics_consent', new.analytics_consent
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists on_users_consent_change on public.users;
create trigger on_users_consent_change
after update of lgpd_consent_at on public.users
for each row execute function public.log_lgpd_consent();
