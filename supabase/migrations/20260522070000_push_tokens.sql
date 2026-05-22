-- Ninho — Fase 8: push_tokens + notification_preferences + helpers.
-- IDEA.md §5.6 + §7.8.
--
-- push_tokens guarda token FCM/APNs por device do usuário. Múltiplos
-- devices por usuário são suportados. Token é único globalmente (caso
-- raro de re-registro do mesmo token em outro user, o último vence).
--
-- notification_preferences: por usuário, horários e canais habilitados.

create type public.push_platform as enum ('android', 'ios', 'web');

create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null unique,
  platform public.push_platform not null,
  device_label text,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index push_tokens_user_idx
  on public.push_tokens (user_id)
  where revoked_at is null;

alter table public.push_tokens enable row level security;

-- Usuário lê os próprios tokens (UI de "devices conectados" futuramente).
create policy push_tokens_select_own
  on public.push_tokens for select
  using (user_id = auth.uid());

-- Sem INSERT/UPDATE/DELETE de cliente: apenas via RPCs SECURITY DEFINER
-- (defense-in-depth: cliente nunca grava token bruto na tabela).

-- ============================================================
-- register_push_token
-- ============================================================
-- Upsert idempotente por token. Se o token já existe e pertencia a outro
-- usuário (re-instalação ou novo login no mesmo device), reassign.
create or replace function public.register_push_token(
  p_token text,
  p_platform public.push_platform,
  p_device_label text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;
  if p_token is null or length(p_token) < 32 then
    raise exception 'Token inválido' using errcode = '22023';
  end if;

  insert into public.push_tokens (user_id, token, platform, device_label)
  values (v_user_id, p_token, p_platform, p_device_label)
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        device_label = coalesce(excluded.device_label, public.push_tokens.device_label),
        last_seen_at = now(),
        revoked_at = null
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.register_push_token(text, public.push_platform, text)
  from public, anon;
grant execute on function public.register_push_token(text, public.push_platform, text)
  to authenticated;

-- ============================================================
-- revoke_push_token (logout / device removed)
-- ============================================================
create or replace function public.revoke_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;
  update public.push_tokens
     set revoked_at = now()
   where token = p_token and user_id = v_user_id and revoked_at is null;
end;
$$;

revoke all on function public.revoke_push_token(text) from public, anon;
grant execute on function public.revoke_push_token(text) to authenticated;

-- ============================================================
-- notification_preferences
-- ============================================================
-- 1 linha por usuário. Horários em "HH:MM" no fuso do ninho ativo.
-- Defaults: 09:00 / 15:00 / 20:00.

create table public.notification_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  push_enabled boolean not null default true,
  morning_time time not null default '09:00',
  afternoon_time time not null default '15:00',
  evening_time time not null default '20:00',
  -- Triggers de eventos (cada um liga/desliga independente).
  event_task_transferred boolean not null default true,
  event_new_member boolean not null default true,
  event_feed_photo boolean not null default true,
  event_streak_risk boolean not null default true,
  event_streak_broken boolean not null default true,
  event_shop_purchase boolean not null default true,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

alter table public.notification_preferences enable row level security;

create policy notification_preferences_select_own
  on public.notification_preferences for select
  using (user_id = auth.uid());

create policy notification_preferences_insert_self
  on public.notification_preferences for insert
  with check (user_id = auth.uid());

create policy notification_preferences_update_own
  on public.notification_preferences for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Auto-cria preferências default ao criar usuário.
create or replace function public.handle_new_user_preferences()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger users_after_insert_preferences
after insert on public.users
for each row execute function public.handle_new_user_preferences();

-- Backfill para usuários existentes.
insert into public.notification_preferences (user_id)
  select id from public.users
  on conflict (user_id) do nothing;
