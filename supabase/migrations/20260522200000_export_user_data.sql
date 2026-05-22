-- Ninho — Fase 11.2 / LGPD §5.10: exportação de dados do usuário.
--
-- RPC SECURITY DEFINER retorna JSON com snapshot dos dados pessoais do
-- caller. Apenas o próprio usuário pode chamar — auth.uid() é resolvido
-- dentro do RPC e usado como filtro em TODAS as queries. Audit log
-- gravado em cada chamada.
--
-- Decisões:
--   * Não inclui PII de OUTROS moradores. environment_members lista só
--     o próprio user_id. task_completions/dust_ledger/streaks/audit_log
--     filtram pelo caller.
--   * Inclui rooms/tasks dos ninhos do caller — são compartilhados,
--     fazem parte do contexto do usuário e o caller já vê via RLS.
--   * Photo paths ficam como referência opaca. Bytes das fotos não
--     entram no JSON (poderia ser GB); usuário baixa via signed URL
--     depois (futuro).

create or replace function public.export_user_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_payload jsonb;
begin
  if v_user_id is null then
    raise exception 'Sem sessão Supabase ativa' using errcode = '28000';
  end if;

  -- Rate-limit: 5 exports / 24h via audit_log. LGPD não exige
  -- retransmissão imediata; protege contra scraping repetido.
  if (
    select count(*) from public.audit_log
     where actor_id = v_user_id
       and action = 'user.export'
       and created_at > now() - interval '24 hours'
  ) >= 5 then
    raise exception 'Limite de exportações por dia atingido' using errcode = '54000';
  end if;

  v_payload := jsonb_build_object(
    'exported_at', now(),
    'user', (
      select to_jsonb(u) - 'id' || jsonb_build_object('id', u.id)
        from public.users u
       where u.id = v_user_id
    ),
    'memberships', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'environment_id', em.environment_id,
          'role', em.role,
          'joined_at', em.joined_at,
          'left_at', em.left_at,
          'environment_name', e.name,
          'timezone', e.timezone
        )
      ), '[]'::jsonb)
        from public.environment_members em
        join public.environments e on e.id = em.environment_id
       where em.user_id = v_user_id
    ),
    'rooms', (
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
        from public.rooms r
       where r.environment_id in (
         select environment_id from public.environment_members
          where user_id = v_user_id and left_at is null
       )
    ),
    'tasks', (
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
        from public.tasks t
       where t.environment_id in (
         select environment_id from public.environment_members
          where user_id = v_user_id and left_at is null
       )
    ),
    'task_completions', (
      select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
        from public.task_completions c
       where c.completed_by = v_user_id
    ),
    'task_transfers', (
      select coalesce(jsonb_agg(to_jsonb(tt)), '[]'::jsonb)
        from public.task_transfers tt
       where tt.from_user_id = v_user_id or tt.to_user_id = v_user_id
    ),
    'dust_ledger', (
      select coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb)
        from public.dust_ledger d
       where d.user_id = v_user_id
    ),
    'streaks', (
      select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
        from public.streaks s
       where s.user_id = v_user_id
    ),
    'audit_log', (
      select coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb)
        from public.audit_log a
       where a.actor_id = v_user_id
    )
  );

  insert into public.audit_log (
    environment_id,
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  )
  values (
    null,
    v_user_id,
    'user.export',
    'user',
    v_user_id,
    jsonb_build_object('bytes', octet_length(v_payload::text))
  );

  return v_payload;
end;
$$;

revoke all on function public.export_user_data() from public, anon;
grant execute on function public.export_user_data() to authenticated;
