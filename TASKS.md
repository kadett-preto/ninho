# TASKS.md — Ninho

> Plano de execução do MVP (Ninho 1.0). Derivado do `IDEA.md`. Atualizar a cada conclusão/mudança de escopo.
>
> **Convenções:**
> - `[ ]` pendente · `[~]` em andamento · `[x]` concluída · `[!]` bloqueada
> - Toda tarefa referencia seção do `IDEA.md` quando aplicável.
> - Toda feature carrega segurança (§7) e testes (§8) embutidos — não criar task separada "adicionar testes depois".
> - Antes de qualquer tela: pedir Stitch (§2). Marcar `[!] aguardando Stitch` se faltar.

---

## Status Geral

- **Fase atual:** 0 — Setup (quase completa)
- **Última atualização:** 2026-05-19
- **Bloqueios ativos:** PostHog API key (0.8) — aguardando criação

---

## Fase 0 — Setup do Projeto

- [x] **0.1.** `flutter create` com estrutura inicial (arch best-practices — skill `flutter-apply-architecture-best-practices`). Flutter 3.44, `lib/{data,domain,ui}` criados.
- [x] **0.2.** `git init` + `.gitignore` Flutter padrão + commit inicial (`36a190e`)
- [x] **0.3.** Projeto Supabase `ninho-dev` (region sa-east) criado; URL+anon em `.env` local. Data API: on. Auto-expose new tables: off (defense-in-depth, §7.1).
- [x] **0.4.** `supabase_flutter` + `flutter_dotenv` integrados (`SupabaseService.init` em `lib/data/services/supabase_client.dart`, bootstrap em `main()`). Smoke real de conexão fica p/ Fase 1 (precisa tabela existir).
- [x] **0.5.** CI baseline (GitHub Actions: format/analyze/test/coverage) em `.github/workflows/flutter-ci.yml`
- [x] **0.6.** Dependabot semanal em `.github/dependabot.yml` (pub + github-actions)
- [x] **0.7.** Sentry mobile integrado (`SentryService`, sampling 0.2, PII scrubbed, §7.5). Pendente: criar projeto `ninho-edge` (Deno) ao iniciar Edge Functions.
- [!] **0.8.** PostHog SDK + flag inicial — aguardando API key
- [x] **0.9.** README mínimo (`README.md`)

---

## Fase 1 — Modelagem de Dados + RLS

> Pré-requisito de quase tudo. Sem isso, nada de feature.

- [ ] **1.1.** Migration: `users` (vinculada `auth.users`)
- [ ] **1.2.** Migration: `environments` + `environment_members`
- [ ] **1.3.** Migration: `rooms`
- [ ] **1.4.** Migration: `tasks` + `task_completions` + `task_transfers`
- [ ] **1.5.** Migration: `streaks` + `dust_ledger`
- [ ] **1.6.** Migration: `feed_events` + `notification_log`
- [ ] **1.7.** Migration: `invites` (token_hash, expires_at, used_at, revoked_at — §7.3)
- [ ] **1.8.** Migration: `audit_log` (§7.5)
- [ ] **1.9.** Policies RLS em todas tabelas com `environment_id`
- [ ] **1.10.** **Testes de RLS (positivos e negativos)** — bloqueador de merge (§8.3)
- [ ] **1.11.** Testes de rollback de cada migration (§8.3)

---

## Fase 2 — Autenticação + Onboarding Inicial

- [!] **2.1.** Tela Splash — aguardando Stitch
- [!] **2.2.** Onboarding 3 cards — aguardando Stitch
- [!] **2.3.** Tela Login (Google + Apple) — aguardando Stitch
- [ ] **2.4.** Wire-up Supabase Auth: Google provider
- [ ] **2.5.** Wire-up Supabase Auth: Apple provider (obrigatório iOS)
- [!] **2.6.** Tela consentimento LGPD — aguardando Stitch (§5.10)
- [ ] **2.7.** Persistência consentimento em `users` + `audit_log`
- [ ] **2.8.** Logout invalida sessão local + servidor (§7.2)
- [ ] **2.9.** Roteamento declarativo inicial (skill `flutter-setup-declarative-routing`)
- [ ] **2.10.** Widget tests de login + onboarding (§8.2)

---

## Fase 3 — Cadastro de Ninho

- [!] **3.1.** Tela "Criar ninho ou entrar" — aguardando Stitch
- [!] **3.2.** Tela criar ninho (nome, fuso, idioma) — aguardando Stitch
- [ ] **3.3.** Lógica de timezone default = device, persistir em `environments.timezone` (§5.2)
- [!] **3.4.** Tela cadastrar cômodos (nome, P/M/G, foto opcional) — aguardando Stitch
- [ ] **3.5.** Upload de foto de cômodo para Supabase Storage com signed URL + EXIF strip (§7.4)
- [ ] **3.6.** Validação tipo/tamanho de arquivo no upload (§7.4)
- [ ] **3.7.** Edge Function: criar ninho (atômico — environment + member owner + audit)
- [ ] **3.8.** Widget + integration tests do fluxo

---

## Fase 4 — Convites

- [!] **4.1.** Tela convidar morador (QR + link + share) — aguardando Stitch
- [ ] **4.2.** Edge Function: gerar convite (token ≥128 bits, hash em DB, TTL 7d — §7.3)
- [ ] **4.3.** Edge Function: aceitar convite (rate-limited, one-time use, valida `auth.uid()`)
- [ ] **4.4.** Edge Function: revogar convite (owner only)
- [!] **4.5.** Tela "Entrar no ninho X?" deep link / QR — aguardando Stitch
- [ ] **4.6.** Mobile scanner QR (skill `flutter-use-http-package` para fetch + `mobile_scanner`)
- [ ] **4.7.** Tour 3 cards pós-entrada — aguardando Stitch
- [ ] **4.8.** Testes negativos de autorização (§8.5): token expirado, token usado, member não-owner tentando revogar

---

## Fase 5 — Geração de Tasks por IA (Onboarding)

- [ ] **5.1.** Edge Function: chamar Claude API com cômodos+tamanhos → lista de tasks sugeridas (§6.3)
- [ ] **5.2.** Prompt template com separação clara sistema/dados-do-usuário (§7.6)
- [ ] **5.3.** Prompt caching habilitado (§6.3) — usar skill `claude-api`
- [ ] **5.4.** Rate limit por usuário/ninho (§7.6)
- [!] **5.5.** Tela revisar/editar/aceitar tasks sugeridas — aguardando Stitch
- [ ] **5.6.** Persistir tasks aceitas em DB
- [ ] **5.7.** Snapshot tests do prompt (§8.4)
- [ ] **5.8.** Eval suite inicial: ninho 3 cômodos, ninho 6 cômodos, ninho com fotos (§8.4)
- [ ] **5.9.** Testes de prompt injection (§8.4) — nome de cômodo malicioso

---

## Fase 6 — Tela Home (Hoje) + Tasks Tab

- [!] **6.1.** Tab bar 5 tabs (Hoje, Tasks, Feed, Loja, Perfil) — aguardando Stitch
- [!] **6.2.** Tela Hoje (lista tasks do dia + streak + poeira) — aguardando Stitch
- [ ] **6.3.** Layout responsivo (skill `flutter-build-responsive-layout`)
- [!] **6.4.** Tela detalhe da task (concluir, foto, transferir) — aguardando Stitch
- [ ] **6.5.** Conclusão de task: marca completion + cancela notifs restantes + credita poeira + emite feed event
- [ ] **6.6.** Upload foto de conclusão (signed URL + EXIF strip + tipo/tamanho)
- [!] **6.7.** Tela Tasks (filtros: minhas/todas/por cômodo) — aguardando Stitch
- [!] **6.8.** Tela criar task manual — aguardando Stitch
- [!] **6.9.** Tela editar task — aguardando Stitch
- [ ] **6.10.** Widget tests + integration test "concluir task com foto" (§8.2)
- [ ] **6.11.** Golden tests dos componentes-chave (§8.2)

---

## Fase 7 — Streak + Jobs

- [ ] **7.1.** Lógica pura de streak (testável unitariamente, §8.2)
- [ ] **7.2.** Edge Function + Supabase Cron: avaliação à meia-noite no fuso do ninho (§5.7)
- [ ] **7.3.** Política de freeze automático (2/mês, individual apenas, não acumulável)
- [ ] **7.4.** Modo "viagem" (owner pausa ninho até 14d/ano, §5.7)
- [ ] **7.5.** Streak quebrado dispara notif (§5.6)
- [ ] **7.6.** Testes com clock mockado (virada de dia, freeze esgotado, modo viagem ativo)

---

## Fase 8 — Notificações Push

- [ ] **8.1.** Configurar FCM (Android) + APNs (iOS) via `firebase_messaging`
- [ ] **8.2.** Persistir token FCM/APNs por device do usuário
- [ ] **8.3.** Invalidar token no logout/remoção (§7.8)
- [ ] **8.4.** Edge Function 3x/dia (09h/15h/20h, fuso do ninho) — verifica task pendente antes de enviar
- [ ] **8.5.** Geração de mensagem personalizada via Claude API (prompt caching, §6.3)
- [ ] **8.6.** Garantir não vazamento de PII de outros ninhos (§7.8)
- [!] **8.7.** Tela configurar horários de notificação — aguardando Stitch
- [ ] **8.8.** Testes: notificação suprimida se task feita; eval qualitativa dos tons (§8.4)
- [ ] **8.9.** Demais gatilhos: task transferida, novo morador, foto no feed, streak em risco/quebrado, compra na loja

---

## Fase 9 — Loja e Economia

- [!] **9.1.** Tela Loja (saldo + itens) — aguardando Stitch
- [ ] **9.2.** Item "Transferência de Task" (30 poeiras, §5.8)
- [ ] **9.3.** Antiabuso: 1x/semana, bloquear destinatário consecutivo, cooldown extra MVP 2-pessoas
- [ ] **9.4.** Edge Function transferência atômica (débito + reassign + audit + notif)
- [ ] **9.5.** Config owner: ligar/desligar item de transferência
- [ ] **9.6.** Histórico de compras
- [ ] **9.7.** Testes: saldo insuficiente, limite semanal, item desativado, destinatário consecutivo

---

## Fase 10 — Feed

- [!] **10.1.** Tela Feed (timeline eventos + fotos) — aguardando Stitch
- [ ] **10.2.** Realtime via Supabase Realtime (§6.2)
- [ ] **10.3.** Moderação: autor deleta foto; owner oculta/deleta qualquer item (§5.9)
- [ ] **10.4.** Botão "denunciar" (sinal interno MVP)
- [ ] **10.5.** Edge Function + Cron domingo à noite: resumo semanal via Claude API
- [ ] **10.6.** Eval suite resumo semanal (§8.4)

---

## Fase 11 — Perfil / Configurações / LGPD

- [!] **11.1.** Tela Perfil/Ninho — aguardando Stitch
- [ ] **11.2.** Exportação de dados em JSON (§5.10)
- [ ] **11.3.** Deletar conta: soft delete + purga em 30d (§5.10)
- [ ] **11.4.** Tratamento owner deletando conta sem transferir (auto-promoção membro mais antigo, §5.5)
- [ ] **11.5.** Arquivar ninho sem membros por 30d → purga (§5.5)
- [ ] **11.6.** Transferência de ownership manual (§5.5)
- [ ] **11.7.** Sair do ninho (§5.5)
- [ ] **11.8.** Configurações do ninho (cômodos, membros, modo viagem, loja on/off)
- [ ] **11.9.** Audit log de todas ações sensíveis (§7.5)
- [ ] **11.10.** Testes negativos de autorização nas Edge Functions (§8.5)

---

## Fase 12 — Internacionalização

- [ ] **12.1.** Setup i18n Flutter (skill `flutter-setup-localization`) — pt-BR + en
- [ ] **12.2.** Strings de UI extraídas para arb
- [ ] **12.3.** Prompts da IA internacionalizados (template por locale)
- [ ] **12.4.** Estrutura preparada para es, fr (mesmo sem tradução)

---

## Fase 13 — Segurança Hardening (transversal)

> Itens que cortam várias fases — revisitar após cada fase relevante.

- [ ] **13.1.** Code review checklist de segurança em PRs que tocam RLS/Edge Functions/auth/convites/prompts (§8.5)
- [ ] **13.2.** Linter de segurança (dart analyze + deno lint + regras custom contra log de PII)
- [ ] **13.3.** Rotação de chaves documentada (§7.7)
- [ ] **13.4.** Threat model §7.10 — validar mitigação de cada ameaça antes do release

---

## Fase 14 — Release MVP

- [ ] **14.1.** Suíte integration tests cobrindo fluxos críticos (onboarding, conclusão com foto, transferência)
- [ ] **14.2.** Cobertura ≥70% global / ≥90% módulos de segurança (§8.6)
- [ ] **14.3.** Smoke test em staging
- [ ] **14.4.** QA manual em device real iOS + Android (§8.7)
- [ ] **14.5.** Paridade visual contra Stitch (§8.7)
- [ ] **14.6.** Configurar RevenueCat (placeholder — se IAP entrar pré-lançamento)
- [ ] **14.7.** Build release iOS (App Store Connect)
- [ ] **14.8.** Build release Android (Play Console)
- [ ] **14.9.** Política de privacidade + termos publicados
- [ ] **14.10.** Publicação

---

## Histórico de Mudanças

- **2026-05-19** — arquivo criado, plano inicial derivado de `IDEA.md` (todas fases pendentes).
- **2026-05-19** — Fase 0 parcialmente concluída: 0.1, 0.2, 0.5, 0.6, 0.9 ✓. 0.3, 0.4, 0.7, 0.8 bloqueadas aguardando contas externas. Commit inicial `36a190e`.
- **2026-05-19** — Supabase dev criado, 0.3 e 0.4 ✓. Commit `20ba10d` (supabase_flutter + flutter_dotenv).
- **2026-05-19** — Sentry mobile integrado (PII scrub + sampling 0.2). 0.7 ✓. Commit `86542f8`.
