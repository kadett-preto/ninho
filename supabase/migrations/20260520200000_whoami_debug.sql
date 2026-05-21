-- DEBUG TEMPORÁRIO: retorna o que o PostgREST vê do JWT. Remover quando
-- o bug RLS de Fase 3 estiver fechado.
create or replace function public.whoami_debug()
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'auth_uid', auth.uid(),
    'auth_role', auth.role(),
    'jwt_sub', current_setting('request.jwt.claim.sub', true),
    'jwt_role', current_setting('request.jwt.claim.role', true),
    'session_user', current_user
  );
$$;

grant execute on function public.whoami_debug() to authenticated, anon;
