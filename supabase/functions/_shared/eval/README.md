# Eval suite — Prompts de IA

> Fase 5.8 + 10.6. Roda fixtures contra Claude (Haiku) para detectar regressão
> de qualidade ou prompt injection sem depender da Edge Function rodando.

## Pré-requisito

- Deno 2.x instalado.
- `ANTHROPIC_API_KEY` no env. **Não commitar.** Ver `docs/KEY_ROTATION.md`.

## Rodar

```bash
export ANTHROPIC_API_KEY=sk-ant-...

# suggest-tasks — 4 fixtures (3 cômodos / 6 mistos / injection / en)
deno run \
  --allow-net=api.anthropic.com \
  --allow-env=ANTHROPIC_API_KEY \
  --allow-write=./eval-results \
  --allow-read=./eval-results \
  supabase/functions/_shared/eval/eval_suggest_tasks.ts

# weekly-summary — 4 fixtures (zero/ativo/cheio/en)
deno run \
  --allow-net=api.anthropic.com \
  --allow-env=ANTHROPIC_API_KEY \
  --allow-write=./eval-results \
  --allow-read=./eval-results \
  supabase/functions/_shared/eval/eval_weekly_summary.ts
```

## Output

Markdown em `eval-results/<kind>_<timestamp>.md` com:

- Tabela pass/fail por fixture + tokens + tempo.
- Texto cru de cada fixture (revisão humana).

Exit code 1 quando alguma assertion falha.

`eval-results/` é gitignored — relatórios ficam locais.

## Quando rodar

- Sempre que mudar `supabase/functions/_shared/prompts.ts`.
- Antes de bumpar versão do modelo Claude.
- Antes de cada release (Fase 14).

## Custo

Cada run completo (~8 chamadas Haiku, max_tokens 400-2048) custa fração de
centavo. Modelo é o `claude-haiku-4-5`.
