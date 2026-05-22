-- Hardening: fixa search_path do trigger genérico de updated_at.
-- Supabase advisor 0011 acusa funções com search_path mutável.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
