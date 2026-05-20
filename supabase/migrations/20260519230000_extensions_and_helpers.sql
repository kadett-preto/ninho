-- Ninho — Fase 1 / Migration 1: extensões e helpers genéricos
-- IDEA.md §7.1 (RLS), §9 (modelo de dados).
--
-- Helpers que dependem de tabelas (is_environment_member etc.) ficam na
-- migration 2, após as tabelas existirem.

create extension if not exists pgcrypto with schema extensions;

-- Trigger genérico para manter updated_at.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
