#!/usr/bin/env bash
set -euo pipefail

TARGET_ENVIRONMENT="${TARGET_ENVIRONMENT:-}"
DEPLOY_DATABASE="${DEPLOY_DATABASE:-true}"
DEPLOY_FUNCTIONS="${DEPLOY_FUNCTIONS:-true}"
UPDATE_FUNCTION_SECRETS="${UPDATE_FUNCTION_SECRETS:-true}"

SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${SUPABASE_PUBLISHABLE:-}}"
export SUPABASE_ANON_KEY

if [[ "$TARGET_ENVIRONMENT" != "staging" && "$TARGET_ENVIRONMENT" != "production" ]]; then
  echo "TARGET_ENVIRONMENT must be staging or production" >&2
  exit 1
fi

required=(
  SUPABASE_ACCESS_TOKEN
  SUPABASE_PROJECT_REF
  SUPABASE_DB_PASSWORD
  SUPABASE_URL
  SUPABASE_ANON_KEY
)

for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required" >&2
    exit 1
  fi
done

if [[ "$UPDATE_FUNCTION_SECRETS" == "true" ]]; then
  secrets=(
    "SUPABASE_URL=${SUPABASE_URL}"
    "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
  )

  if [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
    secrets+=("SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}")
  fi
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    secrets+=("ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
  fi
  if [[ -n "${FIREBASE_SERVICE_ACCOUNT_JSON:-}" ]]; then
    secrets+=("FIREBASE_SERVICE_ACCOUNT_JSON=${FIREBASE_SERVICE_ACCOUNT_JSON}")
  fi
  if [[ -n "${USE_AI:-}" ]]; then
    secrets+=("USE_AI=${USE_AI}")
  fi

  echo "Updating Edge Function secrets for ${TARGET_ENVIRONMENT}"
  supabase secrets set --project-ref "$SUPABASE_PROJECT_REF" "${secrets[@]}"
fi

if [[ "$DEPLOY_DATABASE" == "true" ]]; then
  echo "Linking Supabase project ${SUPABASE_PROJECT_REF}"
  supabase link \
    --project-ref "$SUPABASE_PROJECT_REF" \
    --password "$SUPABASE_DB_PASSWORD" \
    --yes

  echo "Applying database migrations to ${TARGET_ENVIRONMENT}"
  supabase db push --linked --password "$SUPABASE_DB_PASSWORD" --yes
fi

if [[ "$DEPLOY_FUNCTIONS" == "true" ]]; then
  echo "Deploying Edge Functions to ${TARGET_ENVIRONMENT}"
  supabase functions deploy \
    --project-ref "$SUPABASE_PROJECT_REF" \
    --use-api
fi

SMOKE_ENVIRONMENT="$TARGET_ENVIRONMENT" bash scripts/staging_smoke.sh
