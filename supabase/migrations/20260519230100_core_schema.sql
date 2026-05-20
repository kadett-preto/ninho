-- Ninho — Fase 1 / Migration 2: users + environments + environment_members
-- IDEA.md §5.1, §5.2, §5.5, §7.1, §9.

-- ============================================================
-- users
-- ============================================================
-- Perfil ligado a auth.users via id. Soft-delete via deleted_at (§5.10).

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  locale text not null default 'pt-BR',
  lgpd_consent_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger users_set_updated_at
before update on public.users
for each row execute function public.set_updated_at();

alter table public.users enable row level security;

-- Cada usuário só vê e edita o próprio perfil. Para exibir nome de
-- co-moradores na UI, consultar via vista filtrada em outra migration ou
-- via Edge Function — não relaxar esta policy.
create policy users_select_own
  on public.users for select
  using (id = auth.uid());

create policy users_update_own
  on public.users for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy users_insert_self
  on public.users for insert
  with check (id = auth.uid());

-- ============================================================
-- environments (ninhos) — apenas tabela; policies entram após helpers.
-- ============================================================

create table public.environments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id),
  name text not null,
  timezone text not null,
  locale text not null default 'pt-BR',
  transfer_item_enabled boolean not null default true,
  vacation_mode boolean not null default false,
  vacation_days_used_year integer not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger environments_set_updated_at
before update on public.environments
for each row execute function public.set_updated_at();

alter table public.environments enable row level security;

-- ============================================================
-- environment_members — apenas tabela; policies entram após helpers.
-- ============================================================

create type public.environment_role as enum ('owner', 'member');

create table public.environment_members (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role public.environment_role not null default 'member',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  unique (environment_id, user_id)
);

create index environment_members_env_idx on public.environment_members (environment_id) where left_at is null;
create index environment_members_user_idx on public.environment_members (user_id) where left_at is null;

alter table public.environment_members enable row level security;

-- ============================================================
-- Helpers de RLS (dependem de environment_members existir).
-- ============================================================

-- Retorna true se o auth.uid() corrente é membro ativo do environment.
create or replace function public.is_environment_member(env_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
      from public.environment_members
     where environment_id = env_id
       and user_id = auth.uid()
       and left_at is null
  );
$$;

create or replace function public.is_environment_owner(env_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
      from public.environment_members
     where environment_id = env_id
       and user_id = auth.uid()
       and role = 'owner'
       and left_at is null
  );
$$;

revoke all on function public.is_environment_member(uuid) from public;
revoke all on function public.is_environment_owner(uuid) from public;
grant execute on function public.is_environment_member(uuid) to authenticated, anon;
grant execute on function public.is_environment_owner(uuid) to authenticated, anon;

-- ============================================================
-- environments — policies
-- ============================================================

create policy environments_select_member
  on public.environments for select
  using (public.is_environment_member(id));

create policy environments_insert_authenticated
  on public.environments for insert
  with check (owner_id = auth.uid());

create policy environments_update_owner
  on public.environments for update
  using (public.is_environment_owner(id))
  with check (public.is_environment_owner(id));

-- ============================================================
-- environment_members — policies
-- ============================================================

create policy environment_members_select_same_env
  on public.environment_members for select
  using (public.is_environment_member(environment_id));

create policy environment_members_insert_owner
  on public.environment_members for insert
  with check (public.is_environment_owner(environment_id));

create policy environment_members_update_owner_or_self
  on public.environment_members for update
  using (
    public.is_environment_owner(environment_id)
    or user_id = auth.uid()
  )
  with check (
    public.is_environment_owner(environment_id)
    or user_id = auth.uid()
  );

-- ============================================================
-- Trigger: ao criar environment, registrar owner como member.
-- ============================================================
create or replace function public.handle_new_environment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.environment_members (environment_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  return new;
end;
$$;

create trigger environments_after_insert
after insert on public.environments
for each row execute function public.handle_new_environment();
