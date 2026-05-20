-- Ninho — Fase 1 / Migration 5: invites + notification_log + audit_log
-- IDEA.md §5.3, §7.3 (convites), §7.5 (auditoria), §7.8 (notificações).
--
-- Estas tabelas são "só-server": clientes nunca leem ou escrevem direto.
-- Acesso exclusivo por Edge Function via service_role.

-- ============================================================
-- invites
-- ============================================================
-- Armazena apenas o HASH do token (token completo só é exibido para quem
-- gera o convite e nunca trafega para a tabela). Token nominal precisa ter
-- ao menos 128 bits de entropia — geração ocorre em Edge Function.

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  token_hash text not null unique,
  created_by uuid not null references public.users(id),
  expires_at timestamptz not null,
  used_at timestamptz,
  used_by uuid references public.users(id),
  revoked_at timestamptz,
  revoked_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create index invites_env_active_idx on public.invites (environment_id)
  where used_at is null and revoked_at is null;

alter table public.invites enable row level security;

-- Permite que o OWNER do environment liste seus próprios convites (para
-- gerenciar/revogar). Sem INSERT/UPDATE/DELETE de cliente — tudo via
-- Edge Function (service_role bypassa RLS).
create policy invites_select_owner
  on public.invites for select
  using (public.is_environment_owner(environment_id));

-- ============================================================
-- notification_log
-- ============================================================
-- Auditoria de cada disparo de notificação (enviado ou suprimido).
-- Cliente lê apenas as próprias entradas (para mostrar histórico no perfil
-- se a feature for habilitada). service_role escreve.

create table public.notification_log (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete set null,
  channel text not null,        -- 'push' | 'in_app'
  slot text not null,           -- 'morning' | 'afternoon' | 'evening' | 'event'
  scheduled_for timestamptz not null,
  sent_at timestamptz,
  suppressed_reason text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index notification_log_user_idx on public.notification_log (user_id, scheduled_for desc);
create index notification_log_env_idx on public.notification_log (environment_id, scheduled_for desc);

alter table public.notification_log enable row level security;

create policy notification_log_select_own
  on public.notification_log for select
  using (user_id = auth.uid());

-- Sem INSERT/UPDATE/DELETE de cliente.

-- ============================================================
-- audit_log
-- ============================================================
-- Imutável. Owner vê seu próprio environment.

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid references public.environments(id) on delete set null,
  actor_id uuid references public.users(id) on delete set null,
  action text not null,         -- ex.: 'environment.create', 'member.role_changed', 'account.export', 'account.delete'
  target_type text,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_env_idx on public.audit_log (environment_id, created_at desc);
create index audit_log_actor_idx on public.audit_log (actor_id, created_at desc);

alter table public.audit_log enable row level security;

create policy audit_log_select_owner
  on public.audit_log for select
  using (
    environment_id is not null
    and public.is_environment_owner(environment_id)
  );

-- Usuário pode ver entradas onde ele é o actor (ex.: meus próprios exports).
create policy audit_log_select_actor
  on public.audit_log for select
  using (actor_id = auth.uid());

-- Sem INSERT/UPDATE/DELETE de cliente (append-only via service_role).
