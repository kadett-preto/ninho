# Deploy

Ninho uses two Supabase environments:

- `staging`: Supabase project `ninho-dev` (`uzvnvxbemaeoggypvocq`)
- `production`: Supabase project `ninho-prod` (`remmoqsyyscjpyaveuzp`)

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
  - `staging`: `uzvnvxbemaeoggypvocq`
  - `production`: `remmoqsyyscjpyaveuzp`
- `SUPABASE_DB_PASSWORD`
- `SUPABASE_URL`
  - `staging`: `https://uzvnvxbemaeoggypvocq.supabase.co`
  - `production`: `https://remmoqsyyscjpyaveuzp.supabase.co`
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

## Web / PWA

Flutter Web is deployed with GitHub Pages by `.github/workflows/deploy-web.yml`.
The public URL is:

- `https://kadett-preto.github.io/ninho/`

Configure these secrets in the `github-pages` GitHub Environment:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SENTRY_DSN` (optional)
- `POSTHOG_API_KEY` (optional)

Optional environment variable:

- `POSTHOG_HOST` (defaults to `https://us.i.posthog.com`)

The workflow generates the `.env` asset during CI and builds with
`--base-href /ninho/`, so the file is not committed to the repository.

In the repository settings, configure **Pages → Build and deployment → Source**
as **GitHub Actions**.

Supabase Auth must allow this exact redirect URL:

- `https://kadett-preto.github.io/ninho/`

On iOS, users can open the URL in Safari and choose **Share → Add to Home
Screen** to use Ninho as a PWA without App Store distribution.

## Production Project

`ninho-prod` already exists and is healthy. Current known state from Supabase:

- Project ref: `remmoqsyyscjpyaveuzp`
- Region: `us-east-1`
- Database: Postgres 17
- Migrations: none applied yet
- Edge Functions: none deployed yet

Production can be bootstrapped by running the **Deploy Supabase** workflow with:

- `environment`: `production`
- `deploy_database`: `true`
- `deploy_functions`: `true`
- `update_function_secrets`: `true`

Before running it, configure the `production` GitHub Environment secrets above
and set required reviewers. Cost expectation recorded in `TASKS.md`: production
should be planned as paid Supabase (~US$25/month plus usage).
