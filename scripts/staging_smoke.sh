#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-.env}"
SMOKE_ENVIRONMENT="${SMOKE_ENVIRONMENT:-staging}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${SUPABASE_PUBLISHABLE:-}}"

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "SUPABASE_URL is required via env or $ENV_FILE" >&2
  exit 1
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "SUPABASE_ANON_KEY is required via env or $ENV_FILE" >&2
  exit 1
fi

curl_common=(
  --fail
  --silent
  --show-error
  --max-time
  "${SMOKE_TIMEOUT_SECONDS:-15}"
)

check_get() {
  local label="$1"
  local url="$2"
  curl "${curl_common[@]}" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    "$url" \
    >/dev/null
  echo "ok - $label"
}

check_postgrest_rls_denial() {
  local response status body
  response="$(
    curl --silent --show-error --max-time "${SMOKE_TIMEOUT_SECONDS:-15}" \
      --write-out $'\n%{http_code}' \
      -H "apikey: ${SUPABASE_ANON_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
      "${SUPABASE_URL}/rest/v1/rooms?select=id&limit=1"
  )"
  status="${response##*$'\n'}"
  body="${response%$'\n'*}"

  if [[ "$status" != "401" && "$status" != "403" ]]; then
    echo "Expected PostgREST anon read to be denied, got HTTP $status" >&2
    exit 1
  fi

  if [[ "$body" != *"permission denied"* ]]; then
    echo "Expected PostgREST anon read denial body, got: $body" >&2
    exit 1
  fi

  echo "ok - postgrest anon RLS denial"
}

check_function_options() {
  local slug="$1"
  curl "${curl_common[@]}" \
    -X OPTIONS \
    -H "Origin: https://ninho.app" \
    -H "Access-Control-Request-Method: POST" \
    "${SUPABASE_URL}/functions/v1/${slug}" \
    >/dev/null
  echo "ok - edge function ${slug}"
}

check_get "auth settings" "${SUPABASE_URL}/auth/v1/settings"
check_postgrest_rls_denial

functions=(
  create-environment
  create-invite
  accept-invite
  preview-invite
  suggest-tasks
  send-task-reminders
  notify-trigger
  weekly-summary
)

for fn in "${functions[@]}"; do
  check_function_options "$fn"
done

echo "${SMOKE_ENVIRONMENT} smoke passed"
