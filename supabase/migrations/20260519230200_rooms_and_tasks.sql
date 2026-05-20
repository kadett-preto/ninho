-- Ninho — Fase 1 / Migration 3: rooms + tasks + completions + transfers
-- IDEA.md §5.2 (cômodos), §5.4 (tasks), §5.8 (transferência), §7.4 (fotos).

-- ============================================================
-- rooms
-- ============================================================

create type public.room_size as enum ('P', 'M', 'G');

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  name text not null,
  size_category public.room_size not null,
  photo_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index rooms_env_idx on public.rooms (environment_id);

create trigger rooms_set_updated_at
before update on public.rooms
for each row execute function public.set_updated_at();

alter table public.rooms enable row level security;

create policy rooms_select_member
  on public.rooms for select
  using (public.is_environment_member(environment_id));

create policy rooms_insert_member
  on public.rooms for insert
  with check (public.is_environment_member(environment_id));

create policy rooms_update_owner
  on public.rooms for update
  using (public.is_environment_owner(environment_id))
  with check (public.is_environment_owner(environment_id));

create policy rooms_delete_owner
  on public.rooms for delete
  using (public.is_environment_owner(environment_id));

-- ============================================================
-- tasks
-- ============================================================

create type public.task_difficulty as enum ('mamao', 'embacada', 'treta');

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  room_id uuid references public.rooms(id) on delete set null,
  title text not null,
  description text,
  assignee_id uuid references public.users(id) on delete set null,
  difficulty public.task_difficulty not null,
  start_date date not null,
  recurrence_rule text,
  created_by uuid not null references public.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_env_idx on public.tasks (environment_id) where archived_at is null;
create index tasks_assignee_idx on public.tasks (assignee_id) where archived_at is null;
create index tasks_room_idx on public.tasks (room_id);

create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();

alter table public.tasks enable row level security;

create policy tasks_select_member
  on public.tasks for select
  using (public.is_environment_member(environment_id));

create policy tasks_insert_member
  on public.tasks for insert
  with check (
    public.is_environment_member(environment_id)
    and created_by = auth.uid()
  );

-- Member edita tasks atribuídas a si (§5.5); owner edita qualquer.
create policy tasks_update_member_or_owner
  on public.tasks for update
  using (
    public.is_environment_owner(environment_id)
    or (public.is_environment_member(environment_id) and assignee_id = auth.uid())
  )
  with check (
    public.is_environment_owner(environment_id)
    or (public.is_environment_member(environment_id) and assignee_id = auth.uid())
  );

create policy tasks_delete_owner
  on public.tasks for delete
  using (public.is_environment_owner(environment_id));

-- ============================================================
-- task_completions
-- ============================================================

create table public.task_completions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  environment_id uuid not null references public.environments(id) on delete cascade,
  completed_by uuid not null references public.users(id),
  completed_at timestamptz not null default now(),
  photo_path text,
  created_at timestamptz not null default now()
);

create index task_completions_env_idx on public.task_completions (environment_id, completed_at desc);
create index task_completions_task_idx on public.task_completions (task_id, completed_at desc);
create index task_completions_user_idx on public.task_completions (completed_by, completed_at desc);

alter table public.task_completions enable row level security;

create policy task_completions_select_member
  on public.task_completions for select
  using (public.is_environment_member(environment_id));

create policy task_completions_insert_self
  on public.task_completions for insert
  with check (
    public.is_environment_member(environment_id)
    and completed_by = auth.uid()
  );

-- Histórico permanece após saída de membro (§5.5). Sem UPDATE/DELETE
-- de cliente; correções via Edge Function (service_role).

-- ============================================================
-- task_transfers
-- ============================================================
-- Cobre item da loja "Transferência de Task" (§5.8). Mutado apenas
-- por Edge Function (service_role) com checagens antiabuso; clientes só leem.

create table public.task_transfers (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  from_user_id uuid not null references public.users(id),
  to_user_id uuid not null references public.users(id),
  iso_year_week text not null,
  cost_dust integer not null,
  created_at timestamptz not null default now()
);

create index task_transfers_env_week_idx on public.task_transfers (environment_id, iso_year_week);
create index task_transfers_from_idx on public.task_transfers (from_user_id, iso_year_week);

alter table public.task_transfers enable row level security;

create policy task_transfers_select_member
  on public.task_transfers for select
  using (public.is_environment_member(environment_id));

-- Sem policy de INSERT/UPDATE/DELETE: bloqueio implícito para roles
-- authenticated/anon. service_role bypassa RLS — usado em Edge Function.
