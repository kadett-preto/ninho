-- Ninho — task 2.7: triggers de LGPD (IDEA.md §3.10, §7.5).
-- Verifica:
--   1. Inserção em auth.users cria public.users com defaults.
--   2. Update de lgpd_consent_at emite audit_log "consent.lgpd.accepted".

begin;
select plan(6);

-- ---- Setup -----------------------------------------------------------------

insert into auth.users (id, email, raw_user_meta_data)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'alice@test.local',
  '{"full_name":"Alice Teste","locale":"pt-BR"}'::jsonb
);

-- ---- 1. Trigger handle_new_auth_user ---------------------------------------

select results_eq(
  $$select count(*)::int from public.users where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  array[1],
  'Trigger on_auth_user_created cria 1 linha em public.users'
);

select results_eq(
  $$select display_name from public.users where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  array['Alice Teste'::text],
  'display_name extraído de raw_user_meta_data.full_name'
);

select results_eq(
  $$select notifications_consent::int from public.users where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  array[0],
  'notifications_consent default false'
);

select results_eq(
  $$select analytics_consent::int from public.users where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  array[0],
  'analytics_consent default false'
);

-- ---- 2. Trigger log_lgpd_consent -------------------------------------------

update public.users
   set lgpd_consent_at = now(),
       notifications_consent = true,
       analytics_consent = false
 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

select results_eq(
  $$select count(*)::int from public.audit_log
     where actor_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       and action = 'consent.lgpd.accepted'$$,
  array[1],
  'Update lgpd_consent_at gera audit_log row'
);

select results_eq(
  $$select (metadata->>'notifications_consent')::boolean::int
       from public.audit_log
      where actor_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        and action = 'consent.lgpd.accepted'$$,
  array[1],
  'audit_log metadata.notifications_consent = true'
);

select * from finish();
rollback;
