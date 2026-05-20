-- Ninho — Fase 1 / Migration 4: streaks + dust_ledger + feed_events
-- IDEA.md §5.7 (streak), §5.8 (poeira), §5.9 (feed).

-- ============================================================
-- streaks
-- ============================================================
-- Um snapshot por (kind, environment_id, user_id?). user_id é null para
-- streaks de environment. Mutado por job cron à meia-noite no fuso do env.

create type public.streak_kind as enum ('user', 'environment');

create table public.streaks (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  kind public.streak_kind not null,
  current_count integer not null default 0,
  best_count integer not null default 0,
  last_evaluated_at timestamptz,
  last_failed_at timestamptz,
  freezes_left_month integer not null default 2,
  freezes_month_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- environment streak: user_id null + apenas 1 por env.
  -- user streak: user_id not null + apenas 1 por (env, user).
  constraint streaks_user_kind_consistency check (
    (kind = 'user' and user_id is not null)
    or (kind = 'environment' and user_id is null)
  )
);

create unique index streaks_env_user_unique
  on public.streaks (environment_id, kind, coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid));

create trigger streaks_set_updated_at
before update on public.streaks
for each row execute function public.set_updated_at();

alter table public.streaks enable row level security;

-- Member vê streaks do ambiente (kind=environment) e o próprio (kind=user).
create policy streaks_select_visibility
  on public.streaks for select
  using (
    public.is_environment_member(environment_id)
    and (kind = 'environment' or user_id = auth.uid())
  );

-- Sem INSERT/UPDATE/DELETE de cliente: cron/Edge Function via service_role.

-- ============================================================
-- dust_ledger
-- ============================================================
-- Append-only. Cada movimento de poeira é uma linha. Saldo = soma(delta).

create table public.dust_ledger (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  delta integer not null,
  reason text not null,
  related_task_id uuid references public.tasks(id) on delete set null,
  related_completion_id uuid references public.task_completions(id) on delete set null,
  related_transfer_id uuid references public.task_transfers(id) on delete set null,
  created_at timestamptz not null default now()
);

create index dust_ledger_user_idx on public.dust_ledger (user_id, created_at desc);
create index dust_ledger_env_idx on public.dust_ledger (environment_id, created_at desc);

alter table public.dust_ledger enable row level security;

-- Próprio usuário vê seu ledger; co-moradores veem entradas do mesmo env
-- para transparência da loja/transferências.
create policy dust_ledger_select_member
  on public.dust_ledger for select
  using (public.is_environment_member(environment_id));

-- Append-only e somente via service_role.

-- ============================================================
-- feed_events
-- ============================================================
-- Eventos exibidos no Feed (§5.9). Payload jsonb para flexibilidade.

create table public.feed_events (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  actor_id uuid references public.users(id) on delete set null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  hidden_at timestamptz,
  hidden_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create index feed_events_env_created_idx on public.feed_events (environment_id, created_at desc);

alter table public.feed_events enable row level security;

create policy feed_events_select_member
  on public.feed_events for select
  using (
    public.is_environment_member(environment_id)
    and hidden_at is null
  );

-- Owner também enxerga eventos ocultos (para moderação).
create policy feed_events_select_owner_hidden
  on public.feed_events for select
  using (public.is_environment_owner(environment_id));

create policy feed_events_insert_member
  on public.feed_events for insert
  with check (
    public.is_environment_member(environment_id)
    and (actor_id is null or actor_id = auth.uid())
  );

-- Autor da foto deleta o próprio evento; owner oculta qualquer um via UPDATE hidden_at.
create policy feed_events_update_owner_or_actor
  on public.feed_events for update
  using (
    public.is_environment_owner(environment_id)
    or actor_id = auth.uid()
  )
  with check (
    public.is_environment_owner(environment_id)
    or actor_id = auth.uid()
  );

create policy feed_events_delete_actor
  on public.feed_events for delete
  using (
    public.is_environment_member(environment_id)
    and actor_id = auth.uid()
  );
