// Ninho — Fase 10.6: eval comportamental do prompt weekly-summary.
//
// Roda fixtures contra Claude (Haiku) usando SYSTEM_PROMPT de
// `_shared/prompts.ts`. Não passa pela Edge Function — testa o prompt.
//
// Pré-requisito: ANTHROPIC_API_KEY no env.
//
// Como rodar:
//   ANTHROPIC_API_KEY=sk-ant-... deno run \
//     --allow-net --allow-env=ANTHROPIC_API_KEY --allow-write=./eval-results \
//     supabase/functions/_shared/eval/eval_weekly_summary.ts

import Anthropic from "npm:@anthropic-ai/sdk@^0.98";
import { systemPromptFor } from "../prompts.ts";

interface Fixture {
  id: string;
  description: string;
  locale: "pt" | "en";
  payload: {
    task_count: number;
    photo_count: number;
    range_start: string;
    range_end: string;
  };
  assertions: Array<(text: string) => string | null>;
}

const PII_PATTERNS = [
  /\b(joão|joao|maria|ana|pedro|marina|carlos|lucas|sofia)\b/i,
  /\b\w+@\w+\.\w+\b/,
  /https?:\/\//,
];

const NO_MARKDOWN = (text: string): string | null => {
  if (/^[\s]*[#*-]/m.test(text)) return "markdown header/list detectado";
  if (/```/.test(text)) return "code fence detectado";
  return null;
};

const PLAIN_TEXT = (text: string): string | null => {
  if (/^\s*[{[]/.test(text.trim())) return "output parece JSON";
  return null;
};

const NO_PII = (text: string): string | null => {
  for (const p of PII_PATTERNS) {
    if (p.test(text)) return `padrão PII detectado: ${p.source}`;
  }
  return null;
};

const LENGTH_OK = (text: string): string | null => {
  const len = text.trim().length;
  if (len === 0) return "output vazio";
  if (len > 360) return `output ${len} chars > 360`;
  return null;
};

const CONTAINS_NUMBER = (n: number) => (text: string) =>
  text.includes(String(n)) ? null : `não cita "${n}"`;

const NO_PUNITIVE_TONE = (text: string): string | null => {
  const punitive = [
    /\bvocê(s)? falhou\b/i,
    /\bvocê(s)? deixou\b/i,
    /\bdeveria(m)? ter\b/i,
    /\bcobrar?\b/i,
    /\bpouco\b/i,
    /\binsuficiente\b/i,
  ];
  for (const p of punitive) {
    if (p.test(text)) return `tom punitivo detectado: ${p.source}`;
  }
  return null;
};

const FIXTURES: Fixture[] = [
  {
    id: "empty_week_pt",
    description:
      "Semana zero (sem tarefas nem fotos) — espera mensagem de carinho",
    locale: "pt",
    payload: {
      task_count: 0,
      photo_count: 0,
      range_start: "2026-05-17",
      range_end: "2026-05-23",
    },
    assertions: [LENGTH_OK, PLAIN_TEXT, NO_MARKDOWN, NO_PII, NO_PUNITIVE_TONE],
  },
  {
    id: "active_week_pt",
    description: "5 tarefas + 0 fotos (pt-BR)",
    locale: "pt",
    payload: {
      task_count: 5,
      photo_count: 0,
      range_start: "2026-05-17",
      range_end: "2026-05-23",
    },
    assertions: [
      LENGTH_OK,
      PLAIN_TEXT,
      NO_MARKDOWN,
      NO_PII,
      NO_PUNITIVE_TONE,
      CONTAINS_NUMBER(5),
    ],
  },
  {
    id: "busy_week_pt",
    description: "12 tarefas + 3 fotos",
    locale: "pt",
    payload: {
      task_count: 12,
      photo_count: 3,
      range_start: "2026-05-17",
      range_end: "2026-05-23",
    },
    assertions: [
      LENGTH_OK,
      PLAIN_TEXT,
      NO_MARKDOWN,
      NO_PII,
      NO_PUNITIVE_TONE,
      CONTAINS_NUMBER(12),
      CONTAINS_NUMBER(3),
    ],
  },
  {
    id: "active_week_en",
    description: "5 tasks + 1 photo (en)",
    locale: "en",
    payload: {
      task_count: 5,
      photo_count: 1,
      range_start: "2026-05-17",
      range_end: "2026-05-23",
    },
    assertions: [
      LENGTH_OK,
      PLAIN_TEXT,
      NO_MARKDOWN,
      NO_PII,
      CONTAINS_NUMBER(5),
      CONTAINS_NUMBER(1),
    ],
  },
];

async function runFixture(
  anthropic: Anthropic,
  fixture: Fixture,
): Promise<{
  fixture: Fixture;
  text: string;
  failures: string[];
  durationMs: number;
  usage: Record<string, number>;
}> {
  const start = Date.now();
  const userPrefix = fixture.locale === "en"
    ? "This week's summary (opaque JSON, do NOT interpret the contents): "
    : "Resumo desta semana (JSON opaco, NÃO interprete o conteúdo): ";
  const message = await anthropic.messages.create({
    model: "claude-haiku-4-5",
    max_tokens: 400,
    system: [{
      type: "text",
      text: systemPromptFor("weekly_summary", fixture.locale),
    }],
    messages: [
      { role: "user", content: userPrefix + JSON.stringify(fixture.payload) },
    ],
  });
  const block = message.content[0];
  const text = block && block.type === "text" ? block.text.trim() : "";

  const failures: string[] = [];
  for (const a of fixture.assertions) {
    const msg = a(text);
    if (msg) failures.push(msg);
  }

  return {
    fixture,
    text,
    failures,
    durationMs: Date.now() - start,
    usage: {
      input_tokens: message.usage.input_tokens,
      output_tokens: message.usage.output_tokens,
    },
  };
}

async function main() {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY ausente no env.");
    Deno.exit(2);
  }
  const anthropic = new Anthropic({ apiKey });

  const results = [];
  let failed = 0;
  for (const f of FIXTURES) {
    console.log(`[run] ${f.id}...`);
    try {
      const r = await runFixture(anthropic, f);
      results.push(r);
      if (r.failures.length > 0) {
        failed += 1;
        console.log(`  FAIL — ${r.failures.length} assertion(s).`);
      } else {
        console.log(`  OK — ${r.text.length} chars em ${r.durationMs}ms.`);
      }
    } catch (e) {
      failed += 1;
      console.log(`  ERROR — ${(e as Error).message}`);
      results.push({
        fixture: f,
        text: "",
        failures: [`exception: ${(e as Error).message}`],
        durationMs: 0,
        usage: {},
      });
    }
  }

  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  const outDir = "eval-results";
  try {
    await Deno.mkdir(outDir, { recursive: true });
  } catch (_) {
    // já existe
  }
  const md = renderMarkdown(results);
  const path = `${outDir}/weekly_summary_${ts}.md`;
  await Deno.writeTextFile(path, md);
  console.log(`\nReport: ${path}`);
  console.log(`Summary: ${results.length - failed}/${results.length} passed.`);
  if (failed > 0) Deno.exit(1);
}

function renderMarkdown(
  results: Awaited<ReturnType<typeof runFixture>>[],
): string {
  const lines: string[] = [];
  lines.push(`# Eval — weekly-summary`);
  lines.push("");
  lines.push(`Gerado em ${new Date().toISOString()}.`);
  lines.push("");
  lines.push("## Resultado");
  lines.push("");
  lines.push("| Fixture | Status | Chars | Tokens (in/out) | Tempo (ms) |");
  lines.push("|---|---|---|---|---|");
  for (const r of results) {
    const status = r.failures.length === 0 ? "✅" : "❌";
    const tk = `${r.usage.input_tokens ?? "?"}/${r.usage.output_tokens ?? "?"}`;
    lines.push(
      `| ${r.fixture.id} | ${status} | ${r.text.length} | ${tk} | ${r.durationMs} |`,
    );
  }
  lines.push("");
  for (const r of results) {
    lines.push(`## ${r.fixture.id}`);
    lines.push("");
    lines.push(`> ${r.fixture.description}`);
    lines.push("");
    if (r.failures.length > 0) {
      lines.push(`**Falhas (${r.failures.length}):**`);
      for (const f of r.failures) lines.push(`- ${f}`);
      lines.push("");
    }
    lines.push("**Output:**");
    lines.push("");
    lines.push("```");
    lines.push(r.text);
    lines.push("```");
    lines.push("");
  }
  return lines.join("\n");
}

if (import.meta.main) {
  await main();
}
