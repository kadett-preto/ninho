-- Ninho - Fase 10.2: habilita Realtime para o mural.
--
-- Postgres Changes exige que a tabela esteja na publication
-- `supabase_realtime`. A leitura continua protegida por RLS em
-- public.feed_events; o cliente tambem filtra por environment_id.

do $$
begin
  if not exists (
    select 1
      from pg_publication
     where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;

  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'feed_events'
  ) then
    alter publication supabase_realtime add table public.feed_events;
  end if;
end;
$$;
