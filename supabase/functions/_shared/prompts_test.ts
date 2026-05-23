// Ninho — Fase 12.3: tests dos prompts por locale.
import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "jsr:@std/assert@^1.0.0";
import {
  normalizeLocale,
  SUGGEST_TASKS_PROMPTS,
  systemPromptFor,
  WEEKLY_SUMMARY_PROMPTS,
} from "./prompts.ts";

Deno.test("normalizeLocale: aceita pt/pt-BR como pt", () => {
  assertEquals(normalizeLocale("pt"), "pt");
  assertEquals(normalizeLocale("pt-BR"), "pt");
  assertEquals(normalizeLocale("PT_br"), "pt");
});

Deno.test("normalizeLocale: aceita en/en-US como en", () => {
  assertEquals(normalizeLocale("en"), "en");
  assertEquals(normalizeLocale("en-US"), "en");
});

Deno.test("normalizeLocale: locales não suportados caem em pt", () => {
  assertEquals(normalizeLocale("fr"), "pt");
  assertEquals(normalizeLocale("es"), "pt");
  assertEquals(normalizeLocale(null), "pt");
  assertEquals(normalizeLocale(undefined), "pt");
  assertEquals(normalizeLocale(""), "pt");
});

Deno.test("systemPromptFor: weekly_summary muda por locale", () => {
  const pt = systemPromptFor("weekly_summary", "pt-BR");
  const en = systemPromptFor("weekly_summary", "en-US");
  assertStringIncludes(pt, "Ninho");
  assertStringIncludes(pt, "pt-BR");
  assertStringIncludes(en, "Ninho");
  assertStringIncludes(en, "English");
  assert(pt !== en, "pt e en devem diferir");
});

Deno.test("systemPromptFor: suggest_tasks muda por locale", () => {
  const pt = systemPromptFor("suggest_tasks", "pt");
  const en = systemPromptFor("suggest_tasks", "en");
  assertStringIncludes(pt, "mamao/embacada/treta");
  assertStringIncludes(en, "easy/tricky/heavy");
});

Deno.test("invariantes §7.6 — todos os prompts repetem as regras core", () => {
  for (const p of Object.values(WEEKLY_SUMMARY_PROMPTS)) {
    // anti-jailbreak + sem nomes + sem markdown.
    assert(
      /jailbreak/i.test(p),
      "weekly_summary deve mencionar jailbreak",
    );
    assert(p.toLowerCase().includes("markdown"));
  }
  for (const p of Object.values(SUGGEST_TASKS_PROMPTS)) {
    assert(/jailbreak/i.test(p));
    assert(p.toLowerCase().includes("json"));
  }
});
