-- Ninho — fix: client (role authenticated) precisa de DML em notification_preferences.
-- Migration 20260520120200_grant_table_access.sql foi escrita antes da Fase 8 criar
-- a tabela. RLS já restringe por user_id = auth.uid(); falta apenas o grant base
-- exigido pelo PostgREST. Sem isso, /settings/notifications quebra com 42501.

grant select, insert, update on public.notification_preferences to authenticated;
