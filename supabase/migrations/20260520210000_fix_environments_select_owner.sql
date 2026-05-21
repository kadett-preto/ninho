-- Bugfix Fase 3: INSERT ... RETURNING numa policy que faz SELECT USING via
-- subquery em environment_members falha porque o trigger AFTER INSERT
-- (handle_new_environment) ainda não criou a linha de membership na hora
-- em que a RLS de SELECT é avaliada sobre a nova linha pelo RETURNING.
--
-- Solução: a SELECT policy aceita owner_id = auth.uid() como fallback —
-- semanticamente correto (o owner sempre vê o próprio environment) e
-- destrava o INSERT ... RETURNING usado pelo SDK.

drop policy if exists environments_select_member on public.environments;

create policy environments_select_member
  on public.environments for select
  using (
    public.is_environment_member(id)
    or owner_id = auth.uid()
  );

-- Remove o RPC de debug — bug diagnosticado e fechado.
drop function if exists public.whoami_debug();
