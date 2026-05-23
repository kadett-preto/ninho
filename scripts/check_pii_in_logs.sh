#!/usr/bin/env bash
# Ninho — Fase 13.2 / §7.5: PII guard para Edge Functions.
#
# Bloqueia console.log/console.error que vazariam PII em telemetria.
# Convenção do projeto:
#   - Erros logam apenas error.code (status, nunca message com PII).
#   - Nada de display_name/email/title/payload de user em log.
#
# Roda em CI (edge-ci.yml). Localmente:
#   bash scripts/check_pii_in_logs.sh

set -euo pipefail

EDGE_DIR="supabase/functions"
EXIT=0

# Padrões proibidos em chamadas a console.* (qualquer profundidade dentro
# da chamada). Aceita variações de quote.
patterns=(
  "display_name"
  "displayName"
  '\.email'
  "user\.email"
  "task\.title"
  '\.title\b'
  "actor_name"
)

# Lista arquivos .ts (exceto testes — testes podem mencionar campos
# como dados de fixture).
files=$(find "$EDGE_DIR" -name "*.ts" ! -name "*_test.ts")

for pattern in "${patterns[@]}"; do
  # Encontra linhas com console.* + pattern; permite multi-line approx.
  matches=$(grep -nE "console\.(log|warn|error|debug|info).*$pattern" $files || true)
  if [[ -n "$matches" ]]; then
    echo "❌ PII em log proibida (§7.5/§7.8) — padrão: $pattern"
    echo "$matches"
    EXIT=1
  fi
done

if [[ $EXIT -eq 0 ]]; then
  echo "✅ PII guard: nenhum console.* vazando campos sensíveis."
fi

exit $EXIT
