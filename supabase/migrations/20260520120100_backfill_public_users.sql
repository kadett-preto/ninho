-- Ninho — backfill: cria public.users para auth.users que existiam antes do
-- trigger on_auth_user_created (migration 20260520120000). Idempotente.

insert into public.users (id, display_name, locale, created_at)
select
  u.id,
  coalesce(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    split_part(coalesce(u.email, ''), '@', 1)
  ),
  coalesce(u.raw_user_meta_data->>'locale', 'pt-BR'),
  coalesce(u.created_at, now())
from auth.users u
on conflict (id) do nothing;
