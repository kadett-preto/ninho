# Deploy

Ninho uses two Supabase environments:

- `staging`: Supabase project `ninho-dev`
- `production`: Supabase project `ninho-prod`

There is no `hom` environment in the MVP release plan.

## GitHub Environments

Create two GitHub Environments named exactly:

- `staging`
- `production`

Set required reviewers on `production` so production deploys require manual
approval. The workflow already binds each run to the selected environment.

## Required Secrets

Configure these secrets separately in each GitHub Environment:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_DB_PASSWORD`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

`SUPABASE_PUBLISHABLE` is accepted as a fallback for `SUPABASE_ANON_KEY`, but
prefer setting `SUPABASE_ANON_KEY` explicitly because the Flutter client still
uses the legacy env name.

Optional but expected before full production readiness:

- `SUPABASE_SERVICE_ROLE_KEY`
- `ANTHROPIC_API_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON`

Environment variable:

- `USE_AI`: `false` by default; set `true` only when Anthropic billing and eval
  baselines are accepted for that environment.

## Workflow

Run **Deploy Supabase** from GitHub Actions.

Inputs:

- `environment`: `staging` or `production`
- `deploy_database`: applies migrations with `supabase db push`
- `deploy_functions`: deploys all Edge Functions
- `update_function_secrets`: syncs Edge Function secrets before deploy

The deploy script always runs the smoke test at the end:

```bash
bash scripts/deploy_supabase.sh
```

The smoke test validates:

- Auth settings are reachable.
- PostgREST is reachable and anonymous access to `rooms` is denied by RLS/grants.
- CORS/OPTIONS responds for every expected Edge Function.

For local smoke testing against `.env`:

```bash
ENV_FILE=.env SMOKE_ENVIRONMENT=staging bash scripts/staging_smoke.sh
```

## Production Project

`ninho-prod` still needs to be created and configured before the production
environment can run. Cost expectation recorded in `TASKS.md`: production should
be planned as paid Supabase (~US$25/month plus usage).
