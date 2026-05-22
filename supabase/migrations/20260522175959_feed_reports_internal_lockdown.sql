-- Ninho - Fase 10.4: torna feed_event_reports tabela interna.
--
-- A migration anterior criou policies de acesso direto. O produto decidiu
-- tratar denuncia como sinal interno MVP: cliente escreve apenas via RPC
-- report_feed_event e auditoria fica em audit_log.

drop policy if exists feed_event_reports_select_owner_or_reporter
  on public.feed_event_reports;

drop policy if exists feed_event_reports_insert_member
  on public.feed_event_reports;

revoke all on public.feed_event_reports from anon, authenticated;
